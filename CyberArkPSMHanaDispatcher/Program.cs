using System;
using System.Diagnostics;
using System.Collections.Generic;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using System.Windows.Forms;

namespace CyberArkHanaDispatcher
{
    internal static class Program
    {
        [DllImport("user32.dll")]
        private static extern bool SetForegroundWindow(IntPtr hWnd);

        [DllImport("user32.dll")]
        private static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

        [DllImport("user32.dll", CharSet = CharSet.Unicode)]
        private static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);

        [DllImport("user32.dll")]
        private static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);

        [DllImport("user32.dll")]
        private static extern bool EnumChildWindows(IntPtr hWndParent, EnumWindowsProc lpEnumFunc, IntPtr lParam);

        [DllImport("user32.dll", CharSet = CharSet.Unicode)]
        private static extern int GetClassName(IntPtr hWnd, StringBuilder lpClassName, int nMaxCount);

        [DllImport("user32.dll")]
        private static extern IntPtr SendMessage(IntPtr hWnd, uint msg, IntPtr wParam, IntPtr lParam);

        [DllImport("user32.dll")]
        private static extern IntPtr GetDlgItem(IntPtr hDlg, int nIDDlgItem);

        [DllImport("user32.dll")]
        private static extern IntPtr SetFocus(IntPtr hWnd);

        private delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

        private const uint BM_CLICK = 0x00F5;
        private const int IDNO = 7;
        private const int IDCANCEL = 2;
        private const int PSM_LOG_INFO = 1;
        private const int PSM_LOG_ERROR = 3;

        [STAThread]
        private static int Main(string[] args)
        {
            var parsed = ParseArgs(args);
            var psm = TryCreatePsmWrapper();
            LogPsm(psm, "PSMSAPHANAStudioDispatcher started.", PSM_LOG_INFO);

            var host = GetArgOrSession(parsed, psm, "host", "Address", "Machine", "Host");
            var instance = GetArgOrSession(parsed, psm, "instance", "systemnumber", "SystemNumber", "Instance");
            if (string.IsNullOrWhiteSpace(instance) && parsed.ContainsKey("systemnumber"))
            {
                instance = parsed["systemnumber"];
            }

            var user = GetArgOrSession(parsed, psm, "user", "UserName", "Username", "User");

            if (string.IsNullOrWhiteSpace(host) ||
                string.IsNullOrWhiteSpace(instance) ||
                string.IsNullOrWhiteSpace(user))
            {
                PrintUsage("Missing one or more required arguments: --host, --instance, --user");
                LogPsm(psm, "Missing one or more required values: host/instance/user.", PSM_LOG_ERROR);
                TryFinalizePsm(psm);
                return 2;
            }

            string p;
            var studioPath = parsed.TryGetValue("studio-path", out p) && !string.IsNullOrWhiteSpace(p)
                ? p
                : @"C:\Program Files\sap\hdbstudio\hdbstudio.exe";

            string workspaceArg;
            var workspacePath = parsed.TryGetValue("workspace", out workspaceArg) && !string.IsNullOrWhiteSpace(workspaceArg)
                ? workspaceArg
                : GetDefaultWorkspacePath();

            if (!File.Exists(studioPath))
            {
                Console.Error.WriteLine("hdbstudio not found at: " + studioPath);
                LogPsm(psm, "hdbstudio not found at: " + studioPath, PSM_LOG_ERROR);
                TryFinalizePsm(psm);
                return 3;
            }

            try
            {
                Directory.CreateDirectory(workspacePath);
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine("Unable to create or access workspace path: " + workspacePath);
                Console.Error.WriteLine(ex.Message);
                LogPsm(psm, "Workspace access error: " + ex.Message, PSM_LOG_ERROR);
                TryFinalizePsm(psm);
                return 8;
            }

            string pw;
            var password = parsed.TryGetValue("password", out pw) ? pw : Environment.GetEnvironmentVariable("HANA_PASSWORD");
            if (string.IsNullOrWhiteSpace(password))
            {
                password = GetSessionPropertySafe(psm, "Password");
            }
            if (string.IsNullOrEmpty(password))
            {
                Console.Error.WriteLine("No password provided. Pass --password or set HANA_PASSWORD environment variable.");
                LogPsm(psm, "No password provided.", PSM_LOG_ERROR);
                TryFinalizePsm(psm);
                return 4;
            }

            string title;
            var windowTitleContains = parsed.TryGetValue("window-title", out title) && !string.IsNullOrWhiteSpace(title)
                ? title
                : "SAP HANA Studio";

            string passwordTitle;
            var passwordWindowTitleContains = parsed.TryGetValue("password-window-title", out passwordTitle) && !string.IsNullOrWhiteSpace(passwordTitle)
                ? passwordTitle
                : "Database User Logon|Log On|Logon|System Logon|Connect to System";

            string waitMsRaw;
            int waitVal;
            var waitMs = parsed.TryGetValue("wait-ms", out waitMsRaw) && int.TryParse(waitMsRaw, out waitVal)
                ? waitVal
                : 15000;

            var startup = new ProcessStartInfo
            {
                FileName = studioPath,
                Arguments = "-data " + QuoteArg(workspacePath) + " -noPwdStore -h " + QuoteArg(host) + " -n " + QuoteArg(instance) + " -u " + QuoteArg(user),
                UseShellExecute = false,
                WorkingDirectory = Path.GetDirectoryName(studioPath) ?? Environment.CurrentDirectory
            };

            try
            {
                var child = Process.Start(startup);
                if (child != null)
                {
                    TrySendPid(psm, child.Id);
                }
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine("Failed to start SAP HANA Studio: " + ex.Message);
                LogPsm(psm, "Failed to start SAP HANA Studio: " + ex.Message, PSM_LOG_ERROR);
                TryFinalizePsm(psm);
                return 5;
            }

            TryConfirmLauncherWithDefault("SAP HANA Studio Launcher", Math.Min(waitMs, 12000));

            var deadline = DateTime.UtcNow.AddMilliseconds(waitMs);
            IntPtr hwnd = IntPtr.Zero;
            var passwordTyped = false;

            while (DateTime.UtcNow < deadline)
            {
                TryDismissSecureStorageHint();
                TryDismissPasswordRecoverySetup();

                hwnd = FindPasswordWindow(passwordWindowTitleContains);
                if (hwnd != IntPtr.Zero)
                {
                    break;
                }

                Thread.Sleep(400);
            }

            if (hwnd == IntPtr.Zero)
            {
                Console.WriteLine("Password dialog was not detected within wait period. Continuing.");
                LogPsm(psm, "Password dialog not detected in wait window.", PSM_LOG_INFO);

                // Final sweep for late Secure Storage prompts before exiting.
                var finalSweep = DateTime.UtcNow.AddMilliseconds(2500);
                while (DateTime.UtcNow < finalSweep)
                {
                    TryDismissSecureStorageHint();
                    TryDismissPasswordRecoverySetup();
                    Thread.Sleep(200);
                }

                TryFinalizePsm(psm);
                return 0;
            }

            // Before typing, spend 4 seconds suppressing recovery/hint popups.
            var preTypeDeadline = DateTime.UtcNow.AddMilliseconds(4000);
            while (DateTime.UtcNow < preTypeDeadline)
            {
                TryDismissSecureStorageHint();
                TryDismissPasswordRecoverySetup();
                Thread.Sleep(200);
            }

            // Re-acquire the password window in case focus changed during popup suppression.
            hwnd = FindPasswordWindow(passwordWindowTitleContains);
            if (hwnd == IntPtr.Zero)
            {
                Console.WriteLine("Password dialog was closed before typing. Continuing.");
                LogPsm(psm, "Password dialog disappeared before typing.", PSM_LOG_INFO);
                TryFinalizePsm(psm);
                return 0;
            }

            const int SW_RESTORE = 9;
            ShowWindow(hwnd, SW_RESTORE);
            SetForegroundWindow(hwnd);
            Thread.Sleep(600);

            if (!TryFocusPasswordField(hwnd))
            {
                // Fallback: move focus from user name field to password field.
                SendKeys.SendWait("{TAB}");
                Thread.Sleep(150);
            }

            try
            {
                // Escape SendKeys metacharacters so the password is typed literally.
                SendKeys.SendWait(EscapeForSendKeys(password));
                SendKeys.SendWait("{ENTER}");
                passwordTyped = true;
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine("Failed while typing password: " + ex.Message);
                LogPsm(psm, "Failed while typing password: " + ex.Message, PSM_LOG_ERROR);
                TryFinalizePsm(psm);
                return 7;
            }

            if (passwordTyped)
            {
                // Password submission can trigger follow-up security prompt; keep suppressing briefly.
                var postTypeSweep = DateTime.UtcNow.AddMilliseconds(2500);
                while (DateTime.UtcNow < postTypeSweep)
                {
                    TryDismissSecureStorageHint();
                    TryDismissPasswordRecoverySetup();
                    Thread.Sleep(200);
                }
            }

            TryFinalizePsm(psm);
            return 0;
        }

        private static void TrySendPid(object psm, int pid)
        {
            if (psm == null)
            {
                return;
            }

            try
            {
                InvokePsmMethod(psm, "SendPID", pid);
                LogPsm(psm, "Sent child PID to PSM: " + pid, PSM_LOG_INFO);
            }
            catch (Exception ex)
            {
                LogPsm(psm, "SendPID failed: " + ex.Message, PSM_LOG_ERROR);
            }
        }

        private static void TryFinalizePsm(object psm)
        {
            if (psm == null)
            {
                return;
            }

            try
            {
                InvokePsmMethod(psm, "FinalizeDispatcher");
            }
            catch
            {
            }
        }

        private static void LogPsm(object psm, string message, int level)
        {
            if (psm == null)
            {
                return;
            }

            try
            {
                InvokePsmMethod(psm, "LogWrite", message, level);
            }
            catch
            {
            }
        }

        private static string GetArgOrSession(Dictionary<string, string> parsed, object psm, string argName, params string[] sessionPropertyNames)
        {
            string value;
            if (parsed.TryGetValue(argName, out value) && !string.IsNullOrWhiteSpace(value))
            {
                return value;
            }

            for (var i = 0; i < sessionPropertyNames.Length; i++)
            {
                var sessionValue = GetSessionPropertySafe(psm, sessionPropertyNames[i]);
                if (!string.IsNullOrWhiteSpace(sessionValue))
                {
                    return sessionValue;
                }
            }

            return null;
        }

        private static string GetSessionPropertySafe(object psm, string propName)
        {
            if (psm == null || string.IsNullOrWhiteSpace(propName))
            {
                return null;
            }

            try
            {
                var result = InvokePsmMethod(psm, "GetSessionProperty", propName);
                return result as string;
            }
            catch
            {
                return null;
            }
        }

        private static IntPtr FindPasswordWindow(string titleMatchers)
        {
            if (string.IsNullOrWhiteSpace(titleMatchers))
            {
                return IntPtr.Zero;
            }

            var split = titleMatchers.Split(new[] { '|' }, StringSplitOptions.RemoveEmptyEntries);
            for (var i = 0; i < split.Length; i++)
            {
                var matcher = split[i].Trim();
                if (string.IsNullOrWhiteSpace(matcher))
                {
                    continue;
                }

                var hwnd = FindWindowByTitleContains(matcher, "Launcher");
                if (hwnd != IntPtr.Zero)
                {
                    var title = ReadWindowTitle(hwnd);
                    if (title.IndexOf("Secure Storage", StringComparison.OrdinalIgnoreCase) < 0)
                    {
                        return hwnd;
                    }
                }
            }

            return IntPtr.Zero;
        }

        private static string ReadWindowTitle(IntPtr hWnd)
        {
            var text = new StringBuilder(512);
            GetWindowText(hWnd, text, text.Capacity);
            return text.ToString();
        }

        private static string ReadClassName(IntPtr hWnd)
        {
            var text = new StringBuilder(256);
            GetClassName(hWnd, text, text.Capacity);
            return text.ToString();
        }

        private static bool TryDismissSecureStorageHint()
        {
            var hintWindow = FindWindowByTitleContains("Secure Storage - Password Hint Needed", null);
            if (hintWindow == IntPtr.Zero)
            {
                return false;
            }

            const int SW_RESTORE = 9;
            ShowWindow(hintWindow, SW_RESTORE);
            SetForegroundWindow(hintWindow);
            Thread.Sleep(200);

            if (TryClickNoButton(hintWindow))
            {
                Thread.Sleep(300);
                return true;
            }

            // Deterministic keyboard fallback: default focus is Yes, so move right to No and confirm.
            SendKeys.SendWait("{RIGHT}");
            Thread.Sleep(100);
            SendKeys.SendWait("{ENTER}");
            Thread.Sleep(200);

            return false;
        }

        private static bool TryDismissPasswordRecoverySetup()
        {
            var recoveryWindow = FindWindowByTitleContains("Password Recovery", null);
            if (recoveryWindow == IntPtr.Zero)
            {
                return false;
            }

            const int SW_RESTORE = 9;
            ShowWindow(recoveryWindow, SW_RESTORE);
            SetForegroundWindow(recoveryWindow);
            Thread.Sleep(200);

            var cancelButton = GetDlgItem(recoveryWindow, IDCANCEL);
            if (cancelButton != IntPtr.Zero)
            {
                SendMessage(cancelButton, BM_CLICK, IntPtr.Zero, IntPtr.Zero);
                Thread.Sleep(200);
                return true;
            }

            SendKeys.SendWait("{ESC}");
            Thread.Sleep(200);
            return true;
        }

        private static bool TryClickNoButton(IntPtr parentWindow)
        {
            var noButton = GetDlgItem(parentWindow, IDNO);
            if (noButton != IntPtr.Zero)
            {
                SendMessage(noButton, BM_CLICK, IntPtr.Zero, IntPtr.Zero);
                return true;
            }

            var clicked = false;

            EnumChildWindows(parentWindow, (child, _) =>
            {
                var className = ReadClassName(child);
                if (!className.Equals("Button", StringComparison.OrdinalIgnoreCase))
                {
                    return true;
                }

                var caption = ReadWindowTitle(child).Trim();
                if (caption.Equals("No", StringComparison.OrdinalIgnoreCase) ||
                    caption.Equals("&No", StringComparison.OrdinalIgnoreCase))
                {
                    SendMessage(child, BM_CLICK, IntPtr.Zero, IntPtr.Zero);
                    clicked = true;
                    return false;
                }

                return true;
            }, IntPtr.Zero);

            return clicked;
        }

        private static bool TryFocusPasswordField(IntPtr loginWindow)
        {
            var editControls = new List<IntPtr>();

            EnumChildWindows(loginWindow, (child, _) =>
            {
                var className = ReadClassName(child);
                if (className.Equals("Edit", StringComparison.OrdinalIgnoreCase))
                {
                    editControls.Add(child);
                }

                return true;
            }, IntPtr.Zero);

            if (editControls.Count >= 2)
            {
                SetFocus(editControls[1]);
                return true;
            }

            if (editControls.Count == 1)
            {
                SetFocus(editControls[0]);
                return true;
            }

            return false;
        }

        private static bool TryConfirmLauncherWithDefault(string launcherTitleContains, int waitMs)
        {
            var deadline = DateTime.UtcNow.AddMilliseconds(waitMs);

            while (DateTime.UtcNow < deadline)
            {
                var hwnd = FindWindowByTitleContains(launcherTitleContains, null);
                if (hwnd != IntPtr.Zero)
                {
                    const int SW_RESTORE = 9;
                    ShowWindow(hwnd, SW_RESTORE);
                    SetForegroundWindow(hwnd);
                    Thread.Sleep(500);
                    SendKeys.SendWait("{ENTER}");
                    Thread.Sleep(1000);
                    return true;
                }

                Thread.Sleep(300);
            }

            return false;
        }

        private static IntPtr FindWindowByTitleContains(string titleContains, string titleExcludes)
        {
            IntPtr found = IntPtr.Zero;

            EnumWindows((hWnd, _) =>
            {
                var t = ReadWindowTitle(hWnd);

                if (!string.IsNullOrWhiteSpace(t) &&
                    t.IndexOf(titleContains, StringComparison.OrdinalIgnoreCase) >= 0 &&
                    (string.IsNullOrWhiteSpace(titleExcludes) || t.IndexOf(titleExcludes, StringComparison.OrdinalIgnoreCase) < 0))
                {
                    found = hWnd;
                    return false;
                }

                return true;
            }, IntPtr.Zero);

            return found;
        }

        private static string QuoteArg(string value)
        {
            if (string.IsNullOrWhiteSpace(value))
            {
                return "\"\"";
            }

            return value.Contains(" ") || value.Contains("\"")
                ? "\"" + value.Replace("\"", "\\\"") + "\""
                : value;
        }

        private static string EscapeForSendKeys(string value)
        {
            return value
                .Replace("{", "{{}")
                .Replace("}", "{}}")
                .Replace("+", "{+}")
                .Replace("^", "{^}")
                .Replace("%", "{%}")
                .Replace("~", "{~}")
                .Replace("(", "{(}")
                .Replace(")", "{)}")
                .Replace("[", "{[}")
                .Replace("]", "{]}");
        }

        private static Dictionary<string, string> ParseArgs(string[] args)
        {
            var map = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);

            for (var i = 0; i < args.Length; i++)
            {
                var token = args[i];

                if (!token.StartsWith("--", StringComparison.Ordinal))
                {
                    continue;
                }

                var key = token.Substring(2);
                var value = string.Empty;

                if (i + 1 < args.Length && !args[i + 1].StartsWith("--", StringComparison.Ordinal))
                {
                    value = args[i + 1];
                    i++;
                }

                map[key] = value;
            }

            return map;
        }

        private static void PrintUsage(string reason = null)
        {
            if (!string.IsNullOrWhiteSpace(reason))
            {
                Console.Error.WriteLine(reason);
                Console.Error.WriteLine();
            }

            Console.WriteLine("Usage:");
            Console.WriteLine("PSMSAPHANAStudioDispatcher.exe --host <hostname> --instance <instanceNo> --user <dbUser> [--systemnumber <instanceNo>] [--password <password>] [--studio-path <path>] [--workspace <path>] [--window-title <title>] [--password-window-title <title>] [--wait-ms <milliseconds>]");
            Console.WriteLine();
            Console.WriteLine("Notes:");
            Console.WriteLine("- If --password is omitted, HANA_PASSWORD environment variable is used.");
            Console.WriteLine("- When CyberArk dispatcher DLLs are present, missing values are read from session properties.");
            Console.WriteLine("- When CyberArk dispatcher DLLs are present, launched process PID is sent to CyberArk.");
            Console.WriteLine("- Default workspace is %LOCALAPPDATA%\\CyberArk\\hdbstudio\\workspace (override with --workspace).");
            Console.WriteLine("- Password is typed only after a window matching --password-window-title is found.");
            Console.WriteLine("- CyberArk DLLs are optional for building, but required for full in-session dispatcher integration.");
            Console.WriteLine("- Uses SAP's documented startup arguments: -h, -n, -u.");
        }

        private static string GetDefaultWorkspacePath()
        {
            var localAppData = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
            if (string.IsNullOrWhiteSpace(localAppData))
            {
                localAppData = Environment.GetEnvironmentVariable("LOCALAPPDATA");
            }

            if (string.IsNullOrWhiteSpace(localAppData))
            {
                localAppData = Environment.GetEnvironmentVariable("USERPROFILE");
            }

            if (string.IsNullOrWhiteSpace(localAppData))
            {
                localAppData = @"C:\Users\Default";
            }

            return Path.Combine(localAppData, "CyberArk", "hdbstudio", "workspace");
        }

        private static object TryCreatePsmWrapper()
        {
            try
            {
                var baseDir = AppDomain.CurrentDomain.BaseDirectory;
                var managedPath = Path.Combine(baseDir, "PSMDispatcherUtilsManaged.dll");
                if (!File.Exists(managedPath))
                {
                    return null;
                }

                var asm = System.Reflection.Assembly.LoadFrom(managedPath);
                var wrapperType = asm.GetType("PSMDispatcherUtilsManaged.PSMDispatcherUtilsWrapper", false, true);
                if (wrapperType == null)
                {
                    return null;
                }

                return Activator.CreateInstance(wrapperType);
            }
            catch
            {
                return null;
            }
        }

        private static object InvokePsmMethod(object instance, string methodName, params object[] args)
        {
            if (instance == null || string.IsNullOrWhiteSpace(methodName))
            {
                return null;
            }

            var type = instance.GetType();
            var method = type.GetMethod(methodName, System.Reflection.BindingFlags.Public | System.Reflection.BindingFlags.Instance);
            if (method == null)
            {
                return null;
            }

            return method.Invoke(instance, args);
        }
    }
}
