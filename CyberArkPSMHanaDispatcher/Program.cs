using System;
using System.Diagnostics;
using System.Collections.Generic;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using System.Windows.Forms;
using Accessibility;

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

        [DllImport("user32.dll", CharSet = CharSet.Unicode, EntryPoint = "SendMessageW")]
        private static extern IntPtr SendMessageText(IntPtr hWnd, uint msg, IntPtr wParam, StringBuilder lParam);

        [DllImport("user32.dll")]
        private static extern IntPtr GetDlgItem(IntPtr hDlg, int nIDDlgItem);

        [DllImport("user32.dll")]
        private static extern IntPtr SetFocus(IntPtr hWnd);

        [DllImport("user32.dll")]
        private static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);

        [DllImport("user32.dll")]
        private static extern bool SetCursorPos(int x, int y);

        [DllImport("user32.dll")]
        private static extern void mouse_event(uint dwFlags, int dx, int dy, uint dwData, UIntPtr dwExtraInfo);

        [DllImport("user32.dll")]
        private static extern bool IsWindowVisible(IntPtr hWnd);

        [DllImport("user32.dll")]
        private static extern bool IsWindowEnabled(IntPtr hWnd);

        [DllImport("user32.dll", EntryPoint = "GetWindowLongPtrW")]
        private static extern IntPtr GetWindowLongPtr64(IntPtr hWnd, int nIndex);

        [DllImport("user32.dll", EntryPoint = "GetWindowLongW")]
        private static extern int GetWindowLong32(IntPtr hWnd, int nIndex);

        [DllImport("user32.dll")]
        private static extern bool GetCursorPos(out POINT lpPoint);

        [DllImport("user32.dll", SetLastError = true)]
        private static extern bool BlockInput([MarshalAs(UnmanagedType.Bool)] bool fBlockIt);

        [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern IntPtr SetWindowsHookExW(int idHook, HookProc lpfn, IntPtr hMod, uint dwThreadId);

        [DllImport("user32.dll", SetLastError = true)]
        private static extern bool UnhookWindowsHookEx(IntPtr hhk);

        [DllImport("user32.dll")]
        private static extern IntPtr CallNextHookEx(IntPtr hhk, int nCode, IntPtr wParam, IntPtr lParam);

        [DllImport("user32.dll", CharSet = CharSet.Unicode, EntryPoint = "GetMessageW")]
        private static extern int GetMessageW(out MSG lpMsg, IntPtr hWnd, uint wMsgFilterMin, uint wMsgFilterMax);

        [DllImport("user32.dll", CharSet = CharSet.Unicode, EntryPoint = "DispatchMessageW")]
        private static extern IntPtr DispatchMessageW(ref MSG lpMsg);

        [DllImport("user32.dll", CharSet = CharSet.Unicode, EntryPoint = "PostThreadMessageW", SetLastError = true)]
        private static extern bool PostThreadMessageW(uint idThread, uint msg, IntPtr wParam, IntPtr lParam);

        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, EntryPoint = "GetModuleHandleW")]
        private static extern IntPtr GetModuleHandleW(string lpModuleName);

        [DllImport("kernel32.dll")]
        private static extern uint GetCurrentThreadId();

        [DllImport("oleacc.dll")]
        private static extern int AccessibleObjectFromWindow(IntPtr hWnd, uint dwId, ref Guid riid, [MarshalAs(UnmanagedType.Interface)] out object ppvObject);

        [DllImport("oleacc.dll")]
        private static extern int AccessibleChildren(IAccessible paccContainer, int iChildStart, int cChildren, [Out] object[] rgvarChildren, out int pcObtained);

        [StructLayout(LayoutKind.Sequential)]
        private struct POINT
        {
            public int X;
            public int Y;
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct RECT
        {
            public int Left;
            public int Top;
            public int Right;
            public int Bottom;
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct MSG
        {
            public IntPtr hwnd;
            public uint message;
            public IntPtr wParam;
            public IntPtr lParam;
            public uint time;
            public POINT pt;
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct MSLLHOOKSTRUCT
        {
            public POINT pt;
            public uint mouseData;
            public uint flags;
            public uint time;
            public IntPtr dwExtraInfo;
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct KBDLLHOOKSTRUCT
        {
            public uint vkCode;
            public uint scanCode;
            public uint flags;
            public uint time;
            public IntPtr dwExtraInfo;
        }

        private delegate IntPtr HookProc(int nCode, IntPtr wParam, IntPtr lParam);

        private delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

        private const uint BM_CLICK = 0x00F5;
        private const int IDNO = 7;
        private const int IDCANCEL = 2;
        private const int PSM_LOG_INFO = 1;
        private const int PSM_LOG_ERROR = 3;
        private const uint MOUSEEVENTF_LEFTDOWN = 0x0002;
        private const uint MOUSEEVENTF_LEFTUP = 0x0004;
        private const uint MOUSEEVENTF_RIGHTDOWN = 0x0008;
        private const uint MOUSEEVENTF_RIGHTUP = 0x0010;
        private const uint OBJID_CLIENT = 0xFFFFFFFC;
        private const uint WM_GETTEXT = 0x000D;
        private const int GWL_STYLE = -16;
        private const int ES_PASSWORD = 0x0020;
        private const int INPUT_LOCK_WATCHDOG_MS = 180000;
        private const int WH_KEYBOARD_LL = 13;
        private const int WH_MOUSE_LL = 14;
        private const uint LLMHF_INJECTED = 0x00000001;
        private const uint LLKHF_INJECTED = 0x00000010;
        private const uint WM_QUIT = 0x0012;

        private static int inputLocked;
        private static Thread inputHookThread;
        private static uint inputHookThreadId;
        private static IntPtr keyboardHook;
        private static IntPtr mouseHook;
        private static HookProc keyboardHookProc;
        private static HookProc mouseHookProc;

        [STAThread]
        private static int Main(string[] args)
        {
            AppDomain.CurrentDomain.ProcessExit += delegate { EndInputLock(); };
            AppDomain.CurrentDomain.UnhandledException += delegate { EndInputLock(); };

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
            var database = GetArgOrSession(parsed, psm, "database", "Database", "DatabaseName", "DBName");
            if (string.IsNullOrWhiteSpace(database))
            {
                database = GetArgOrSession(parsed, psm, "tenant", "Tenant", "TenantDB", "TenantDatabase");
            }
            var port = GetArgOrSession(parsed, psm, "port", "Port", "ServerPort", "SqlPort");
            if (string.IsNullOrWhiteSpace(port) && parsed.ContainsKey("sqlport"))
            {
                port = parsed["sqlport"];
            }

            if (string.IsNullOrWhiteSpace(host) ||
                string.IsNullOrWhiteSpace(instance) ||
                string.IsNullOrWhiteSpace(user))
            {
                PrintUsage("Missing one or more required arguments: --host, --instance, --user");
                LogPsm(psm, "Missing one or more required values: host/instance/user.", PSM_LOG_ERROR);
                TryFinalizePsm(psm);
                return 2;
            }

            if (!string.IsNullOrWhiteSpace(port))
            {
                int parsedPort;
                if (!int.TryParse(port, out parsedPort) || parsedPort < 1 || parsedPort > 65535)
                {
                    PrintUsage("Invalid port value. Use --port with a number from 1 to 65535.");
                    LogPsm(psm, "Invalid port value: " + port, PSM_LOG_ERROR);
                    TryFinalizePsm(psm);
                    return 9;
                }

                port = parsedPort.ToString();
            }

            string p;
            var studioPath = parsed.TryGetValue("studio-path", out p) && !string.IsNullOrWhiteSpace(p)
                ? p
                : @"C:\Program Files\sap\hdbstudio\hdbstudio.exe";

            string workspaceArg;
            var explicitWorkspace = parsed.TryGetValue("workspace", out workspaceArg) && !string.IsNullOrWhiteSpace(workspaceArg);
            var workspacePath = explicitWorkspace ? workspaceArg : GetSessionWorkspacePath();

            if (!File.Exists(studioPath))
            {
                Console.Error.WriteLine("hdbstudio not found at: " + studioPath);
                LogPsm(psm, "hdbstudio not found at: " + studioPath, PSM_LOG_ERROR);
                TryFinalizePsm(psm);
                return 3;
            }

            if (!explicitWorkspace)
            {
                PurgeOldSessionWorkspaces(psm, workspacePath);
            }

            try
            {
                Directory.CreateDirectory(workspacePath);
                LogPsm(psm, "Using workspace: " + workspacePath, PSM_LOG_INFO);
                SuppressWelcomeScreen(psm, workspacePath);
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

            string startupDelayRaw;
            int startupDelayVal;
            var startupDelayMs = parsed.TryGetValue("startup-delay-ms", out startupDelayRaw) && int.TryParse(startupDelayRaw, out startupDelayVal)
                ? startupDelayVal
                : 8000;

            var hostWithPort = string.IsNullOrWhiteSpace(port) ? host : host + ":" + port;
            var mode = ResolveMode(parsed, database);

            var startup = new ProcessStartInfo
            {
                FileName = studioPath,
                Arguments = "-data " + QuoteArg(workspacePath) + " -noPwdStore",
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

            // A cold start needs time before the workbench accepts input.
            if (startupDelayMs > 0)
            {
                LogPsm(psm, "Waiting " + startupDelayMs + " ms for SAP HANA Studio to load.", PSM_LOG_INFO);
                SweepStartupPopups(startupDelayMs);
            }

            BeginInputLock(psm);

            OpenAddSystemWizard(psm, waitMs);

            var wizard = WaitForWizardPage("Specify System", waitMs);
            if (wizard == IntPtr.Zero)
            {
                Console.WriteLine("Specify System wizard not detected. Falling back to logon dialog handling.");
                LogPsm(psm, "Specify System wizard not detected; using logon dialog fallback.", PSM_LOG_INFO);
                var fallbackResult = RunPasswordDialogFallback(psm, passwordWindowTitleContains, password, waitMs);
                TryFinalizePsm(psm);
                return fallbackResult;
            }

            if (!FillSpecifySystemPage(wizard, hostWithPort, instance, mode, database))
            {
                Console.Error.WriteLine("Failed to populate the Specify System page.");
                LogPsm(psm, "Failed to populate Specify System page.", PSM_LOG_ERROR);
                TryFinalizePsm(psm);
                return 10;
            }

            LogPsm(psm, "Specify System page set: host=" + hostWithPort + ", instance=" + instance + ", mode=" + mode + ".", PSM_LOG_INFO);

            if (WizardReportsDuplicate(wizard))
            {
                var existingResult = ConnectToExistingSystem(psm, wizard, host, user, passwordWindowTitleContains, password, waitMs);
                TryFinalizePsm(psm);
                return existingResult;
            }

            if (!ClickWizardButtonWhenEnabled(wizard, "Next", Math.Min(waitMs, 20000)))
            {
                Console.Error.WriteLine("Next button was not found or stayed disabled on the Specify System page.");
                LogPsm(psm, "Next button not clickable on Specify System page.", PSM_LOG_ERROR);
                TryFinalizePsm(psm);
                return 11;
            }

            Thread.Sleep(1500);
            TryDismissSecureStorageHint();
            TryDismissPasswordRecoverySetup();

            wizard = WaitForWizardPage("Connection Properties", Math.Min(waitMs, 15000));
            if (wizard == IntPtr.Zero)
            {
                Console.Error.WriteLine("Connection properties page was not detected.");
                LogPsm(psm, "Connection properties page not detected after Next.", PSM_LOG_ERROR);
                TryFinalizePsm(psm);
                return 12;
            }

            if (!FillCredentialsPage(wizard, user, password, Math.Min(waitMs, 20000)))
            {
                Console.Error.WriteLine("Failed to populate credentials on the connection properties page.");
                LogPsm(psm, "Failed to populate credentials page.", PSM_LOG_ERROR);
                TryFinalizePsm(psm);
                return 13;
            }

            LogPsm(psm, "Credentials entered for user: " + user + ".", PSM_LOG_INFO);

            if (WizardReportsDuplicate(wizard))
            {
                var existingResult = ConnectToExistingSystem(psm, wizard, host, user, passwordWindowTitleContains, password, waitMs);
                TryFinalizePsm(psm);
                return existingResult;
            }

            if (!ClickWizardButtonWhenEnabled(wizard, "Finish", Math.Min(waitMs, 20000)))
            {
                LogPsm(psm, "Finish button not clickable; submitting with ENTER.", PSM_LOG_INFO);
                SendKeys.SendWait("{ENTER}");
            }

            EndInputLock();

            var postFinishSweep = DateTime.UtcNow.AddMilliseconds(5000);
            while (DateTime.UtcNow < postFinishSweep)
            {
                TryDismissSecureStorageHint();
                TryDismissPasswordRecoverySetup();
                Thread.Sleep(200);
            }

            LogPsm(psm, "Connection wizard completed.", PSM_LOG_INFO);
            TryFinalizePsm(psm);
            return 0;
        }

        private static string ResolveMode(Dictionary<string, string> parsed, string database)
        {
            string requested;
            if (parsed.TryGetValue("mode", out requested) && !string.IsNullOrWhiteSpace(requested))
            {
                var normalized = requested.Trim().ToLowerInvariant();
                if (normalized.StartsWith("single", StringComparison.Ordinal))
                {
                    return "single";
                }

                if (normalized.StartsWith("system", StringComparison.Ordinal))
                {
                    return "systemdb";
                }

                if (normalized.StartsWith("tenant", StringComparison.Ordinal) || normalized.StartsWith("multi", StringComparison.Ordinal))
                {
                    return string.IsNullOrWhiteSpace(database) ? "systemdb" : "tenant";
                }
            }

            if (string.IsNullOrWhiteSpace(database))
            {
                return "single";
            }

            return database.Trim().Equals("SYSTEMDB", StringComparison.OrdinalIgnoreCase) ? "systemdb" : "tenant";
        }

        private static IntPtr WaitForWizardPage(string heading, int waitMs)
        {
            var deadline = DateTime.UtcNow.AddMilliseconds(waitMs);

            while (DateTime.UtcNow < deadline)
            {
                TryDismissSecureStorageHint();
                TryDismissPasswordRecoverySetup();

                var wizard = FindWindowContainingText(heading);
                if (wizard != IntPtr.Zero)
                {
                    ShowWindow(wizard, 9);
                    SetForegroundWindow(wizard);
                    Thread.Sleep(400);
                    return wizard;
                }

                Thread.Sleep(400);
            }

            return IntPtr.Zero;
        }

        // Wizard pages are identified by their heading label because the shell title stays generic.
        private static IntPtr FindWindowContainingText(string text)
        {
            IntPtr found = IntPtr.Zero;

            EnumWindows((hWnd, _) =>
            {
                if (!IsWindowVisible(hWnd))
                {
                    return true;
                }

                if (!WindowContainsText(hWnd, text))
                {
                    return true;
                }

                found = hWnd;
                return false;
            }, IntPtr.Zero);

            return found;
        }

        private static bool WindowContainsText(IntPtr window, string text)
        {
            var contains = false;

            EnumChildWindows(window, (child, _) =>
            {
                if (!IsWindowVisible(child))
                {
                    return true;
                }

                if (ReadWindowTitle(child).IndexOf(text, StringComparison.OrdinalIgnoreCase) >= 0)
                {
                    contains = true;
                    return false;
                }

                return true;
            }, IntPtr.Zero);

            return contains;
        }

        private static IntPtr WaitForMainWindow(int waitMs)
        {
            var deadline = DateTime.UtcNow.AddMilliseconds(waitMs);

            while (DateTime.UtcNow < deadline)
            {
                TryDismissSecureStorageHint();
                TryDismissPasswordRecoverySetup();

                var main = FindWindowByTitleContains("SAP HANA Studio", "Launcher");
                if (main != IntPtr.Zero)
                {
                    return main;
                }

                Thread.Sleep(400);
            }

            return IntPtr.Zero;
        }

        private static bool OpenAddSystemWizard(object psm, int waitMs)
        {
            var main = WaitForMainWindow(waitMs);
            if (main == IntPtr.Zero)
            {
                LogPsm(psm, "SAP HANA Studio main window not detected.", PSM_LOG_ERROR);
                return false;
            }

            SetForegroundWindow(main);
            Thread.Sleep(1200);

            // The Secure Storage hint can surface a few seconds after the window appears.
            SweepStartupPopups(4000);

            TryCloseWelcomeTab(psm, main);

            for (var attempt = 0; attempt < 3; attempt++)
            {
                if (FindWindowContainingText("Specify System") != IntPtr.Zero)
                {
                    return true;
                }

                if (TryPressToolbarAddSystem(main))
                {
                    if (WaitForWizardPage("Specify System", Math.Min(waitMs, 15000)) != IntPtr.Zero)
                    {
                        LogPsm(psm, "Add System wizard opened from the Systems view toolbar.", PSM_LOG_INFO);
                        return true;
                    }
                }

                Thread.Sleep(1000);
            }

            LogPsm(psm, "Add System toolbar button not found.", PSM_LOG_ERROR);
            return false;
        }

        // A fresh workspace opens the Welcome page, which hides the Systems view toolbar.
        private static bool TryCloseWelcomeTab(object psm, IntPtr main)
        {
            RECT tab;
            if (!FindWelcomeTabRect(main, out tab))
            {
                return false;
            }

            for (var attempt = 0; attempt < 3; attempt++)
            {
                var centerY = tab.Top + ((tab.Bottom - tab.Top) / 2);

                // The close X sits just inside the right edge of the tab.
                ClickAt(tab.Right - 10, centerY, false);
                Thread.Sleep(900);

                if (!FindWelcomeTabRect(main, out tab))
                {
                    break;
                }

                centerY = tab.Top + ((tab.Bottom - tab.Top) / 2);
                ClickAt(tab.Left + Math.Min(25, (tab.Right - tab.Left) / 2), centerY, false);
                Thread.Sleep(400);
                SendKeys.SendWait("^w");
                Thread.Sleep(900);

                if (!FindWelcomeTabRect(main, out tab))
                {
                    break;
                }

                SendKeys.SendWait("^{F4}");
                Thread.Sleep(900);

                if (!FindWelcomeTabRect(main, out tab))
                {
                    break;
                }
            }

            var closed = !FindWelcomeTabRect(main, out tab);
            LogPsm(psm, closed ? "Welcome tab closed." : "Welcome tab could not be closed.", closed ? PSM_LOG_INFO : PSM_LOG_ERROR);
            Thread.Sleep(600);
            return closed;
        }

        private static bool FindWelcomeTabRect(IntPtr main, out RECT rect)
        {
            // Tab strips are drawn, not real windows, so only the accessible tree exposes them.
            return FindAccessibleItemRect(GetAccessibleObject(main), "Welcome", 60, 0, out rect);
        }

        private static bool FindAccessibleItemRect(IAccessible container, string caption, int maxHeight, int depth, out RECT rect)
        {
            rect = new RECT();

            if (container == null || depth > 10)
            {
                return false;
            }

            int childCount;
            try
            {
                childCount = container.accChildCount;
            }
            catch
            {
                return false;
            }

            if (childCount <= 0)
            {
                return false;
            }

            var children = new object[childCount];
            int obtained;
            if (AccessibleChildren(container, 0, childCount, children, out obtained) != 0)
            {
                return false;
            }

            for (var i = 0; i < obtained; i++)
            {
                var nested = children[i] as IAccessible;
                if (nested != null)
                {
                    if (TryGetAccessibleRect(nested, 0, caption, maxHeight, out rect) ||
                        FindAccessibleItemRect(nested, caption, maxHeight, depth + 1, out rect))
                    {
                        return true;
                    }

                    continue;
                }

                if (children[i] != null && TryGetAccessibleRect(container, children[i], caption, maxHeight, out rect))
                {
                    return true;
                }
            }

            return false;
        }

        private static bool TryGetAccessibleRect(IAccessible accessible, object childId, string caption, int maxHeight, out RECT rect)
        {
            rect = new RECT();

            string name;
            try
            {
                name = accessible.get_accName(childId);
            }
            catch
            {
                return false;
            }

            if (string.IsNullOrWhiteSpace(name) ||
                name.Replace("&", string.Empty).Trim().IndexOf(caption, StringComparison.OrdinalIgnoreCase) < 0)
            {
                return false;
            }

            try
            {
                int left, top, width, height;
                accessible.accLocation(out left, out top, out width, out height, childId);
                if (width <= 0 || height <= 0)
                {
                    return false;
                }

                if (maxHeight > 0 && (height > maxHeight || width > 500))
                {
                    return false;
                }

                rect.Left = left;
                rect.Top = top;
                rect.Right = left + width;
                rect.Bottom = top + height;
                return true;
            }
            catch
            {
                return false;
            }
        }

        private static bool TryPressToolbarAddSystem(IntPtr main)
        {
            var toolbars = new List<IntPtr>();

            EnumChildWindows(main, (child, _) =>
            {
                if (IsWindowVisible(child) && ReadClassName(child).Equals("ToolbarWindow32", StringComparison.OrdinalIgnoreCase))
                {
                    toolbars.Add(child);
                }

                return true;
            }, IntPtr.Zero);

            for (var i = 0; i < toolbars.Count; i++)
            {
                if (TryPressAccessibleItem(GetAccessibleObject(toolbars[i]), "Add System", "Archive", 0))
                {
                    return true;
                }
            }

            return TryPressAccessibleItem(GetAccessibleObject(main), "Add System", "Archive", 0);
        }

        private static IAccessible GetAccessibleObject(IntPtr window)
        {
            var iid = new Guid("618736e0-3c3d-11cf-810c-00aa00389b71");
            object accessible;

            if (AccessibleObjectFromWindow(window, OBJID_CLIENT, ref iid, out accessible) != 0)
            {
                return null;
            }

            return accessible as IAccessible;
        }

        private static bool TryPressAccessibleItem(IAccessible container, string caption, string excludeCaption, int depth)
        {
            if (container == null || depth > 6)
            {
                return false;
            }

            int childCount;
            try
            {
                childCount = container.accChildCount;
            }
            catch
            {
                return false;
            }

            if (childCount <= 0)
            {
                return false;
            }

            var children = new object[childCount];
            int obtained;
            if (AccessibleChildren(container, 0, childCount, children, out obtained) != 0)
            {
                return false;
            }

            for (var i = 0; i < obtained; i++)
            {
                var nested = children[i] as IAccessible;
                if (nested != null)
                {
                    if (TryPressAccessibleChild(nested, 0, caption, excludeCaption) ||
                        TryPressAccessibleItem(nested, caption, excludeCaption, depth + 1))
                    {
                        return true;
                    }

                    continue;
                }

                if (children[i] != null && TryPressAccessibleChild(container, children[i], caption, excludeCaption))
                {
                    return true;
                }
            }

            return false;
        }

        private static bool TryPressAccessibleChild(IAccessible accessible, object childId, string caption, string excludeCaption)
        {
            string name;
            try
            {
                name = accessible.get_accName(childId);
            }
            catch
            {
                return false;
            }

            if (string.IsNullOrWhiteSpace(name))
            {
                return false;
            }

            name = name.Replace("&", string.Empty).Trim();
            if (name.IndexOf(caption, StringComparison.OrdinalIgnoreCase) < 0)
            {
                return false;
            }

            if (!string.IsNullOrWhiteSpace(excludeCaption) &&
                name.IndexOf(excludeCaption, StringComparison.OrdinalIgnoreCase) >= 0)
            {
                return false;
            }

            // Default action presses the control without moving the mouse.
            try
            {
                accessible.accDoDefaultAction(childId);
                Thread.Sleep(600);
                return true;
            }
            catch
            {
            }

            try
            {
                int left, top, width, height;
                accessible.accLocation(out left, out top, out width, out height, childId);
                if (width > 0 && height > 0)
                {
                    ClickAt(left + (width / 2), top + (height / 2), false);
                    return true;
                }
            }
            catch
            {
            }

            return false;
        }

        private static bool FillSpecifySystemPage(IntPtr wizard, string hostWithPort, string instance, string mode, string database)
        {
            ShowWindow(wizard, 9);
            SetForegroundWindow(wizard);
            Thread.Sleep(600);

            var hostEdit = FindEditNearLabel(wizard, "Host Name");
            if (hostEdit == IntPtr.Zero)
            {
                var edits = GetChildControls(wizard, "Edit");
                if (edits.Count == 0)
                {
                    return false;
                }

                hostEdit = edits[0];
            }

            ClickAndType(hostEdit, hostWithPort);
            AcceptHostHistoryEntry(wizard, hostEdit, hostWithPort);
            TabAndType(instance);

            if (mode == "single")
            {
                return ClickControlByCaption(wizard, "Button", "Single container");
            }

            if (!ClickControlByCaption(wizard, "Button", "Multiple containers"))
            {
                return false;
            }

            Thread.Sleep(500);

            if (mode == "systemdb")
            {
                return ClickControlByCaption(wizard, "Button", "System database");
            }

            if (!ClickControlByCaption(wizard, "Button", "Tenant database"))
            {
                return false;
            }

            Thread.Sleep(500);

            // Focus sits on the tenant radio, so one tab reaches the tenant Name field.
            TabAndType(database);
            return true;
        }

        // The host field offers a history list that can swallow the next keystrokes.
        private static void AcceptHostHistoryEntry(IntPtr wizard, IntPtr hostEdit, string expected)
        {
            Thread.Sleep(700);

            if (FindHistoryPopup(wizard, hostEdit) == IntPtr.Zero)
            {
                return;
            }

            SendKeys.SendWait("{DOWN}");
            Thread.Sleep(300);
            SendKeys.SendWait("{ENTER}");
            Thread.Sleep(500);

            if (ReadControlText(hostEdit).Trim().Equals(expected, StringComparison.OrdinalIgnoreCase))
            {
                return;
            }

            ClickAndType(hostEdit, expected);
            Thread.Sleep(500);

            if (FindHistoryPopup(wizard, hostEdit) != IntPtr.Zero)
            {
                SendKeys.SendWait("{ENTER}");
                Thread.Sleep(400);
            }
        }

        private static IntPtr FindHistoryPopup(IntPtr wizard, IntPtr anchor)
        {
            RECT anchorRect;
            if (!GetWindowRect(anchor, out anchorRect))
            {
                return IntPtr.Zero;
            }

            IntPtr found = IntPtr.Zero;

            EnumWindows((hWnd, _) =>
            {
                if (hWnd == wizard || !IsWindowVisible(hWnd))
                {
                    return true;
                }

                RECT rect;
                if (!GetWindowRect(hWnd, out rect))
                {
                    return true;
                }

                if (rect.Right - rect.Left < 60 || rect.Bottom - rect.Top < 25)
                {
                    return true;
                }

                if (rect.Top < anchorRect.Bottom - 10 || rect.Top > anchorRect.Bottom + 60)
                {
                    return true;
                }

                if (Math.Abs(rect.Left - anchorRect.Left) > 250)
                {
                    return true;
                }

                found = hWnd;
                return false;
            }, IntPtr.Zero);

            return found;
        }

        private static string ReadControlText(IntPtr control)
        {
            var text = new StringBuilder(512);
            SendMessageText(control, WM_GETTEXT, new IntPtr(text.Capacity), text);
            return text.ToString();
        }

        private static IntPtr FindEditNearLabel(IntPtr window, string labelText)
        {
            var labels = GetChildControls(window, "Static");
            var labelFound = false;
            var labelRect = new RECT();

            for (var i = 0; i < labels.Count; i++)
            {
                if (ReadWindowTitle(labels[i]).Replace("&", string.Empty).IndexOf(labelText, StringComparison.OrdinalIgnoreCase) < 0)
                {
                    continue;
                }

                if (GetWindowRect(labels[i], out labelRect))
                {
                    labelFound = true;
                    break;
                }
            }

            if (!labelFound)
            {
                return IntPtr.Zero;
            }

            var edits = GetChildControls(window, "Edit");
            var best = IntPtr.Zero;
            var bestDistance = int.MaxValue;

            for (var i = 0; i < edits.Count; i++)
            {
                if (!IsWindowEnabled(edits[i]))
                {
                    continue;
                }

                RECT editRect;
                if (!GetWindowRect(edits[i], out editRect))
                {
                    continue;
                }

                var sameRow = editRect.Top <= labelRect.Bottom && editRect.Bottom >= labelRect.Top;
                if (!sameRow || editRect.Left < labelRect.Left)
                {
                    continue;
                }

                var distance = editRect.Left - labelRect.Right;
                if (distance < bestDistance)
                {
                    bestDistance = distance;
                    best = edits[i];
                }
            }

            return best;
        }

        private static bool FillCredentialsPage(IntPtr wizard, string user, string password, int waitMs)
        {
            ShowWindow(wizard, 9);
            SetForegroundWindow(wizard);
            Thread.Sleep(500);

            ClickControlByCaption(wizard, "Button", "Authentication by database user");
            Thread.Sleep(400);

            var deadline = DateTime.UtcNow.AddMilliseconds(waitMs);
            var userEdit = IntPtr.Zero;

            while (DateTime.UtcNow < deadline)
            {
                if (IndexOfPasswordEdit(GetChildControls(wizard, "Edit")) >= 0)
                {
                    userEdit = FindEditNearLabel(wizard, "User Name");
                    if (userEdit != IntPtr.Zero)
                    {
                        break;
                    }
                }

                TryDismissSecureStorageHint();
                TryDismissPasswordRecoverySetup();
                Thread.Sleep(300);
            }

            if (userEdit == IntPtr.Zero)
            {
                return false;
            }

            ClickAndType(userEdit, user);
            TabAndType(password);
            return true;
        }

        private static int IndexOfPasswordEdit(List<IntPtr> edits)
        {
            for (var i = 0; i < edits.Count; i++)
            {
                if (IsWindowEnabled(edits[i]) && (GetControlStyle(edits[i]) & ES_PASSWORD) == ES_PASSWORD)
                {
                    return i;
                }
            }

            return -1;
        }

        private static bool ClickWizardButtonWhenEnabled(IntPtr wizard, string caption, int waitMs)
        {
            var deadline = DateTime.UtcNow.AddMilliseconds(waitMs);

            while (DateTime.UtcNow < deadline)
            {
                if (ClickWizardButton(wizard, caption))
                {
                    return true;
                }

                TryDismissSecureStorageHint();
                TryDismissPasswordRecoverySetup();
                Thread.Sleep(300);
            }

            return false;
        }

        private static bool ClickWizardButton(IntPtr wizard, string caption)
        {
            ShowWindow(wizard, 9);
            SetForegroundWindow(wizard);
            Thread.Sleep(300);

            return ClickControlByCaption(wizard, "Button", caption);
        }

        private static bool ClickControlByCaption(IntPtr parent, string className, string caption)
        {
            var controls = GetChildControls(parent, className);

            for (var i = 0; i < controls.Count; i++)
            {
                var control = controls[i];
                if (!IsWindowVisible(control) || !IsWindowEnabled(control))
                {
                    continue;
                }

                var text = ReadWindowTitle(control).Replace("&", string.Empty).Trim();
                if (text.Length == 0)
                {
                    continue;
                }

                if (text.Equals(caption, StringComparison.OrdinalIgnoreCase) ||
                    text.IndexOf(caption, StringComparison.OrdinalIgnoreCase) >= 0)
                {
                    ClickControl(control);
                    return true;
                }
            }

            return false;
        }

        private static List<IntPtr> GetChildControls(IntPtr parent, string className)
        {
            var controls = new List<IntPtr>();
            var rects = new List<RECT>();

            EnumChildWindows(parent, (child, _) =>
            {
                if (!ReadClassName(child).Equals(className, StringComparison.OrdinalIgnoreCase))
                {
                    return true;
                }

                // Eclipse keeps previous wizard pages alive but hidden, so only visible controls are usable.
                if (!IsWindowVisible(child))
                {
                    return true;
                }

                RECT rect;
                if (!GetWindowRect(child, out rect))
                {
                    return true;
                }

                controls.Add(child);
                rects.Add(rect);
                return true;
            }, IntPtr.Zero);

            // Order controls the way they appear on screen so index-based lookups stay stable.
            for (var i = 1; i < controls.Count; i++)
            {
                var control = controls[i];
                var rect = rects[i];
                var j = i - 1;

                while (j >= 0 && (rects[j].Top > rect.Top || (rects[j].Top == rect.Top && rects[j].Left > rect.Left)))
                {
                    controls[j + 1] = controls[j];
                    rects[j + 1] = rects[j];
                    j--;
                }

                controls[j + 1] = control;
                rects[j + 1] = rect;
            }

            return controls;
        }

        private static void ClickControl(IntPtr control)
        {
            RECT rect;
            if (!GetWindowRect(control, out rect))
            {
                SendMessage(control, BM_CLICK, IntPtr.Zero, IntPtr.Zero);
                return;
            }

            ClickAt(
                rect.Left + ((rect.Right - rect.Left) / 2),
                rect.Top + ((rect.Bottom - rect.Top) / 2),
                false);
        }

        private static void ClickAt(int x, int y, bool rightButton)
        {
            POINT original;
            var hasOriginal = GetCursorPos(out original);

            SetCursorPos(x, y);
            Thread.Sleep(120);
            mouse_event(rightButton ? MOUSEEVENTF_RIGHTDOWN : MOUSEEVENTF_LEFTDOWN, 0, 0, 0, UIntPtr.Zero);
            Thread.Sleep(60);
            mouse_event(rightButton ? MOUSEEVENTF_RIGHTUP : MOUSEEVENTF_LEFTUP, 0, 0, 0, UIntPtr.Zero);
            Thread.Sleep(250);

            if (hasOriginal)
            {
                SetCursorPos(original.X, original.Y);
            }
        }

        // SAP HANA Studio refuses duplicates, so the existing entry is used instead of adding a new one.
        private static bool WizardReportsDuplicate(IntPtr wizard)
        {
            return wizard != IntPtr.Zero && WindowContainsText(wizard, "already exists");
        }

        private static int ConnectToExistingSystem(object psm, IntPtr wizard, string host, string user, string passwordWindowTitleContains, string password, int waitMs)
        {
            LogPsm(psm, "System already exists in the Systems view; cancelling the wizard and logging on to the existing entry.", PSM_LOG_INFO);
            Console.WriteLine("System already exists. Logging on to the existing entry instead.");

            if (!ClickWizardButton(wizard, "Cancel"))
            {
                SendKeys.SendWait("{ESC}");
            }

            Thread.Sleep(1200);
            TryDismissSecureStorageHint();
            TryDismissPasswordRecoverySetup();

            var main = WaitForMainWindow(Math.Min(waitMs, 15000));
            if (main == IntPtr.Zero)
            {
                LogPsm(psm, "Main window not detected after cancelling the wizard.", PSM_LOG_ERROR);
                return 14;
            }

            SetForegroundWindow(main);
            Thread.Sleep(800);

            if (!TryOpenExistingSystem(main, host, user))
            {
                Console.Error.WriteLine("Existing system entry was not found in the Systems view.");
                LogPsm(psm, "Existing system entry not found in the Systems view.", PSM_LOG_ERROR);
                return 15;
            }

            return RunPasswordDialogFallback(psm, passwordWindowTitleContains, password, Math.Min(waitMs, 20000));
        }

        private static bool TryOpenExistingSystem(IntPtr main, string host, string user)
        {
            var shortHost = host.Split('.')[0];
            var tokens = new List<string>();
            if (!string.IsNullOrWhiteSpace(user))
            {
                tokens.Add(user);
            }
            if (!string.IsNullOrWhiteSpace(shortHost))
            {
                tokens.Add(shortHost);
            }

            return TryActivateAccessibleItem(GetAccessibleObject(main), tokens, 0);
        }

        private static bool TryActivateAccessibleItem(IAccessible container, List<string> tokens, int depth)
        {
            if (container == null || depth > 8)
            {
                return false;
            }

            int childCount;
            try
            {
                childCount = container.accChildCount;
            }
            catch
            {
                return false;
            }

            if (childCount <= 0)
            {
                return false;
            }

            var children = new object[childCount];
            int obtained;
            if (AccessibleChildren(container, 0, childCount, children, out obtained) != 0)
            {
                return false;
            }

            for (var i = 0; i < obtained; i++)
            {
                var nested = children[i] as IAccessible;
                if (nested != null)
                {
                    if (TryActivateAccessibleChild(nested, 0, tokens) ||
                        TryActivateAccessibleItem(nested, tokens, depth + 1))
                    {
                        return true;
                    }

                    continue;
                }

                if (children[i] != null && TryActivateAccessibleChild(container, children[i], tokens))
                {
                    return true;
                }
            }

            return false;
        }

        private static bool TryActivateAccessibleChild(IAccessible accessible, object childId, List<string> tokens)
        {
            string name;
            try
            {
                name = accessible.get_accName(childId);
            }
            catch
            {
                return false;
            }

            if (string.IsNullOrWhiteSpace(name))
            {
                return false;
            }

            var matched = false;
            for (var i = 0; i < tokens.Count; i++)
            {
                if (name.IndexOf(tokens[i], StringComparison.OrdinalIgnoreCase) >= 0)
                {
                    matched = true;
                    break;
                }
            }

            if (!matched)
            {
                return false;
            }

            try
            {
                // TAKEFOCUS | TAKESELECTION
                accessible.accSelect(3, childId);
                Thread.Sleep(300);
            }
            catch
            {
            }

            try
            {
                int left, top, width, height;
                accessible.accLocation(out left, out top, out width, out height, childId);
                if (width <= 0 || height <= 0)
                {
                    return false;
                }

                DoubleClickAt(left + (width / 2), top + (height / 2));
                return true;
            }
            catch
            {
                return false;
            }
        }

        private static void DoubleClickAt(int x, int y)
        {
            POINT original;
            var hasOriginal = GetCursorPos(out original);

            SetCursorPos(x, y);
            Thread.Sleep(120);

            for (var i = 0; i < 2; i++)
            {
                mouse_event(MOUSEEVENTF_LEFTDOWN, 0, 0, 0, UIntPtr.Zero);
                Thread.Sleep(40);
                mouse_event(MOUSEEVENTF_LEFTUP, 0, 0, 0, UIntPtr.Zero);
                Thread.Sleep(40);
            }

            Thread.Sleep(400);

            if (hasOriginal)
            {
                SetCursorPos(original.X, original.Y);
            }
        }

        private static void ClickAndType(IntPtr control, string text)
        {
            ClickControl(control);
            Thread.Sleep(250);
            ReplaceFocusedFieldText(text);
        }

        private static void TabAndType(string text)
        {
            SendKeys.SendWait("{TAB}");
            Thread.Sleep(300);
            ReplaceFocusedFieldText(text);
        }

        private static void ReplaceFocusedFieldText(string text)
        {
            SendKeys.SendWait("^a");
            Thread.Sleep(100);
            SendKeys.SendWait("{DEL}");
            Thread.Sleep(100);

            if (!string.IsNullOrEmpty(text))
            {
                SendKeys.SendWait(EscapeForSendKeys(text));
            }

            Thread.Sleep(300);
        }

        private static int GetControlStyle(IntPtr control)
        {
            if (IntPtr.Size == 8)
            {
                return unchecked((int)(GetWindowLongPtr64(control, GWL_STYLE).ToInt64() & 0xFFFFFFFF));
            }

            return GetWindowLong32(control, GWL_STYLE);
        }

        private static int RunPasswordDialogFallback(object psm, string passwordWindowTitleContains, string password, int waitMs)
        {
            var deadline = DateTime.UtcNow.AddMilliseconds(waitMs);
            IntPtr hwnd = IntPtr.Zero;

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
                LogPsm(psm, "Password dialog not detected in wait window.", PSM_LOG_INFO);

                var finalSweep = DateTime.UtcNow.AddMilliseconds(2500);
                while (DateTime.UtcNow < finalSweep)
                {
                    TryDismissSecureStorageHint();
                    TryDismissPasswordRecoverySetup();
                    Thread.Sleep(200);
                }

                return 0;
            }

            ShowWindow(hwnd, 9);
            SetForegroundWindow(hwnd);
            Thread.Sleep(600);

            if (!TryFocusPasswordField(hwnd))
            {
                SendKeys.SendWait("{TAB}");
                Thread.Sleep(150);
            }

            try
            {
                SendKeys.SendWait(EscapeForSendKeys(password));
                SendKeys.SendWait("{ENTER}");
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine("Failed while typing password: " + ex.Message);
                LogPsm(psm, "Failed while typing password: " + ex.Message, PSM_LOG_ERROR);
                return 7;
            }

            var postTypeSweep = DateTime.UtcNow.AddMilliseconds(2500);
            while (DateTime.UtcNow < postTypeSweep)
            {
                TryDismissSecureStorageHint();
                TryDismissPasswordRecoverySetup();
                Thread.Sleep(200);
            }

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

        // Low-level hooks swallow real mouse/keyboard events while injected automation input passes through.
        private static void BeginInputLock(object psm)
        {
            if (Interlocked.CompareExchange(ref inputLocked, 1, 0) != 0)
            {
                return;
            }

            BlockInput(true);

            var ready = new ManualResetEvent(false);

            inputHookThread = new Thread(delegate () { RunInputHookLoop(ready); });
            inputHookThread.IsBackground = true;
            inputHookThread.Start();
            ready.WaitOne(3000);

            if (keyboardHook == IntPtr.Zero && mouseHook == IntPtr.Zero)
            {
                LogPsm(psm, "Could not install input hooks (error " + Marshal.GetLastWin32Error() + "); continuing unlocked.", PSM_LOG_INFO);
            }
            else
            {
                LogPsm(psm, "User input blocked during wizard automation.", PSM_LOG_INFO);
            }

            // Safety net so a hung run cannot leave the desktop locked.
            var watchdog = new Thread(delegate ()
            {
                Thread.Sleep(INPUT_LOCK_WATCHDOG_MS);
                EndInputLock();
            });
            watchdog.IsBackground = true;
            watchdog.Start();
        }

        private static void RunInputHookLoop(ManualResetEvent ready)
        {
            var module = GetModuleHandleW(null);
            keyboardHookProc = KeyboardHookCallback;
            mouseHookProc = MouseHookCallback;

            inputHookThreadId = GetCurrentThreadId();
            keyboardHook = SetWindowsHookExW(WH_KEYBOARD_LL, keyboardHookProc, module, 0);
            mouseHook = SetWindowsHookExW(WH_MOUSE_LL, mouseHookProc, module, 0);
            ready.Set();

            MSG msg;
            while (GetMessageW(out msg, IntPtr.Zero, 0, 0) > 0)
            {
                DispatchMessageW(ref msg);
            }

            if (keyboardHook != IntPtr.Zero)
            {
                UnhookWindowsHookEx(keyboardHook);
                keyboardHook = IntPtr.Zero;
            }

            if (mouseHook != IntPtr.Zero)
            {
                UnhookWindowsHookEx(mouseHook);
                mouseHook = IntPtr.Zero;
            }
        }

        private static IntPtr KeyboardHookCallback(int nCode, IntPtr wParam, IntPtr lParam)
        {
            if (nCode >= 0 && inputLocked == 1)
            {
                var data = (KBDLLHOOKSTRUCT)Marshal.PtrToStructure(lParam, typeof(KBDLLHOOKSTRUCT));
                if ((data.flags & LLKHF_INJECTED) == 0)
                {
                    return new IntPtr(1);
                }
            }

            return CallNextHookEx(keyboardHook, nCode, wParam, lParam);
        }

        private static IntPtr MouseHookCallback(int nCode, IntPtr wParam, IntPtr lParam)
        {
            if (nCode >= 0 && inputLocked == 1)
            {
                var data = (MSLLHOOKSTRUCT)Marshal.PtrToStructure(lParam, typeof(MSLLHOOKSTRUCT));
                if ((data.flags & LLMHF_INJECTED) == 0)
                {
                    return new IntPtr(1);
                }
            }

            return CallNextHookEx(mouseHook, nCode, wParam, lParam);
        }

        private static void EndInputLock()
        {
            if (Interlocked.CompareExchange(ref inputLocked, 0, 1) != 1)
            {
                return;
            }

            try
            {
                BlockInput(false);
            }
            catch
            {
            }

            try
            {
                if (inputHookThreadId != 0)
                {
                    PostThreadMessageW(inputHookThreadId, WM_QUIT, IntPtr.Zero, IntPtr.Zero);
                }

                var thread = inputHookThread;
                if (thread != null)
                {
                    thread.Join(2000);
                }
            }
            catch
            {
            }

            inputHookThread = null;
            inputHookThreadId = 0;
        }

        private static void TryFinalizePsm(object psm)
        {
            EndInputLock();

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

        private static void SweepStartupPopups(int waitMs)
        {
            var deadline = DateTime.UtcNow.AddMilliseconds(waitMs);

            while (DateTime.UtcNow < deadline)
            {
                TryDismissSecureStorageHint();
                TryDismissPasswordRecoverySetup();
                Thread.Sleep(500);
            }
        }

        private static IntPtr FindSecureStorageHintWindow()
        {
            var hintWindow = FindWindowByTitleContains("Password Hint", null);
            if (hintWindow == IntPtr.Zero)
            {
                hintWindow = FindWindowByTitleContains("Secure Storage - ", null);
            }

            return hintWindow;
        }

        private static bool TryDismissSecureStorageHint()
        {
            var hintWindow = FindSecureStorageHintWindow();
            if (hintWindow == IntPtr.Zero)
            {
                return false;
            }

            const int SW_RESTORE = 9;
            ShowWindow(hintWindow, SW_RESTORE);
            SetForegroundWindow(hintWindow);
            Thread.Sleep(250);

            for (var attempt = 0; attempt < 3; attempt++)
            {
                var noButton = FindButtonByCaption(hintWindow, "No");

                if (attempt == 0 && noButton != IntPtr.Zero)
                {
                    SendMessage(noButton, BM_CLICK, IntPtr.Zero, IntPtr.Zero);
                }
                else if (attempt == 1 && noButton != IntPtr.Zero)
                {
                    ClickControl(noButton);
                }
                else
                {
                    // Default focus is Yes, so move right to No and confirm.
                    SetForegroundWindow(hintWindow);
                    Thread.Sleep(150);
                    SendKeys.SendWait("{RIGHT}");
                    Thread.Sleep(120);
                    SendKeys.SendWait("{ENTER}");
                }

                Thread.Sleep(600);

                if (FindSecureStorageHintWindow() == IntPtr.Zero)
                {
                    return true;
                }
            }

            return false;
        }

        private static IntPtr FindButtonByCaption(IntPtr parentWindow, string caption)
        {
            IntPtr found = IntPtr.Zero;

            EnumChildWindows(parentWindow, (child, _) =>
            {
                if (!ReadClassName(child).Equals("Button", StringComparison.OrdinalIgnoreCase))
                {
                    return true;
                }

                if (!ReadWindowTitle(child).Replace("&", string.Empty).Trim().Equals(caption, StringComparison.OrdinalIgnoreCase))
                {
                    return true;
                }

                found = child;
                return false;
            }, IntPtr.Zero);

            return found;
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

            noButton = FindButtonByCaption(parentWindow, "No");
            if (noButton == IntPtr.Zero)
            {
                return false;
            }

            SendMessage(noButton, BM_CLICK, IntPtr.Zero, IntPtr.Zero);
            return true;
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
            Console.WriteLine("PSMSAPHANAStudioDispatcherSelectDB.exe --host <hostname> --instance <instanceNo> --user <dbUser> [--port <portNo>] [--database <tenantDb>] [--tenant <tenantDb>] [--mode single|multiple|tenant|system] [--systemnumber <instanceNo>] [--password <password>] [--studio-path <path>] [--workspace <path>] [--window-title <title>] [--password-window-title <title>] [--wait-ms <milliseconds>] [--startup-delay-ms <milliseconds>]");
            Console.WriteLine();
            Console.WriteLine("Notes:");
            Console.WriteLine("- If --password is omitted, HANA_PASSWORD environment variable is used.");
            Console.WriteLine("- When CyberArk dispatcher DLLs are present, missing values are read from session properties.");
            Console.WriteLine("- When CyberArk dispatcher DLLs are present, launched process PID is sent to CyberArk.");
            Console.WriteLine("- Each run gets a fresh workspace under %LOCALAPPDATA%\\CyberArk\\hdbstudio\\sessions and older ones are deleted (override with --workspace).");
            Console.WriteLine("- --startup-delay-ms waits for the studio to finish loading before automation starts (default 8000).");
            Console.WriteLine("- CyberArk DLLs are optional for building, but required for full in-session dispatcher integration.");
            Console.WriteLine("- hdbstudio is started only with -data and -noPwdStore; no -h, -n or -u arguments are passed.");
            Console.WriteLine("- The Add System wizard is opened by pressing the Systems view toolbar button.");
            Console.WriteLine("- Host Name is typed as host:port when --port is given.");
            Console.WriteLine("- --database selects Multiple containers + Tenant database and types the tenant name.");
            Console.WriteLine("- --mode system (or --database SYSTEMDB) selects Multiple containers + System database.");
            Console.WriteLine("- --mode single selects Single container.");
            Console.WriteLine("- User name and password are typed on the connection properties page, then Finish is clicked.");
            Console.WriteLine("- If the wizard is not detected, the classic logon dialog fallback is used.");
        }

        // Pre-seeding the workbench preference keeps the Welcome/intro page from opening at all.
        private static void SuppressWelcomeScreen(object psm, string workspacePath)
        {
            try
            {
                var settings = Path.Combine(workspacePath, @".metadata\.plugins\org.eclipse.core.runtime\.settings");
                Directory.CreateDirectory(settings);

                var prefs = Path.Combine(settings, "org.eclipse.ui.workbench.prefs");
                if (!File.Exists(prefs))
                {
                    File.WriteAllText(prefs, "eclipse.preferences.version=1\nshowIntro=false\n");
                }

                var idePrefs = Path.Combine(settings, "org.eclipse.ui.ide.prefs");
                if (!File.Exists(idePrefs))
                {
                    File.WriteAllText(idePrefs, "eclipse.preferences.version=1\nshowIntro=false\n");
                }
            }
            catch (Exception ex)
            {
                LogPsm(psm, "Could not pre-disable the Welcome page: " + ex.Message, PSM_LOG_INFO);
            }
        }

        private static string GetSessionWorkspaceRoot()
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
                localAppData = Path.GetTempPath();
            }

            return Path.Combine(localAppData, "CyberArk", "hdbstudio", "sessions");
        }

        // A fresh workspace per session keeps the Systems view empty so the wizard never hits a duplicate.
        private static string GetSessionWorkspacePath()
        {
            var name = "ws-" + DateTime.Now.ToString("yyyyMMdd-HHmmss") + "-" + Process.GetCurrentProcess().Id;
            return Path.Combine(GetSessionWorkspaceRoot(), name);
        }

        private static void PurgeOldSessionWorkspaces(object psm, string keepPath)
        {
            var root = GetSessionWorkspaceRoot();
            var legacy = GetLegacyWorkspacePath();
            var removed = 0;
            var skipped = 0;

            try
            {
                Directory.CreateDirectory(root);
            }
            catch (Exception ex)
            {
                LogPsm(psm, "Unable to prepare workspace root " + root + ": " + ex.Message, PSM_LOG_ERROR);
                return;
            }

            var candidates = new List<string>();

            try
            {
                candidates.AddRange(Directory.GetDirectories(root));
            }
            catch (Exception ex)
            {
                LogPsm(psm, "Unable to list old workspaces: " + ex.Message, PSM_LOG_ERROR);
            }

            if (Directory.Exists(legacy))
            {
                candidates.Add(legacy);
            }

            for (var i = 0; i < candidates.Count; i++)
            {
                var candidate = candidates[i];
                if (string.Equals(Path.GetFullPath(candidate).TrimEnd('\\'), Path.GetFullPath(keepPath).TrimEnd('\\'), StringComparison.OrdinalIgnoreCase))
                {
                    continue;
                }

                if (TryDeleteDirectory(candidate))
                {
                    removed++;
                }
                else
                {
                    // A locked .metadata means another studio instance still owns that workspace.
                    skipped++;
                }
            }

            LogPsm(psm, "Workspace cleanup: removed " + removed + ", in use " + skipped + ".", PSM_LOG_INFO);
        }

        private static bool TryDeleteDirectory(string path)
        {
            for (var attempt = 0; attempt < 2; attempt++)
            {
                try
                {
                    ClearReadOnlyAttributes(path);
                    Directory.Delete(path, true);
                    return true;
                }
                catch
                {
                    Thread.Sleep(200);
                }
            }

            return !Directory.Exists(path);
        }

        private static void ClearReadOnlyAttributes(string path)
        {
            try
            {
                foreach (var file in Directory.GetFiles(path, "*", SearchOption.AllDirectories))
                {
                    try
                    {
                        File.SetAttributes(file, FileAttributes.Normal);
                    }
                    catch
                    {
                    }
                }
            }
            catch
            {
            }
        }

        private static string GetLegacyWorkspacePath()
        {
            var localAppData = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
            if (string.IsNullOrWhiteSpace(localAppData))
            {
                localAppData = Environment.GetEnvironmentVariable("LOCALAPPDATA");
            }

            if (string.IsNullOrWhiteSpace(localAppData))
            {
                return string.Empty;
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
