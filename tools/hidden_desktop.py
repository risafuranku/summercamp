"""Run the game's windowed tests on a desktop of their own, out of the way of whoever sits at
the PC (the user, 22. 11.: "it drives me mad how you keep jerking my mouse while I work").

A test window that captures the mouse for the first-person look clips and centres the real
cursor even unfocused; a window on another Windows desktop (CreateDesktop, the same window
station) has its own pointer and keyboard and is never shown, and it still renders, so the
shots come out as before.

    python tools/hidden_desktop.py [--log FILE] -- <program> <args...>
        runs one program there and waits; its output into FILE (else this console)

    from hidden_desktop import popen          (in the tests' own runners)
    p = popen([godot, ...], stdout=open(log, "w"), env=env)   # like subprocess.Popen
"""
import ctypes
import ctypes.wintypes as wt
import os
import subprocess
import sys

DESKTOP = "summercamp_tests"
GENERIC_ALL = 0x10000000
STARTF_USESTDHANDLES = 0x00000100
CREATE_UNICODE_ENVIRONMENT = 0x00000400
HANDLE_FLAG_INHERIT = 0x00000001

k32 = ctypes.WinDLL("kernel32", use_last_error=True)
u32 = ctypes.WinDLL("user32", use_last_error=True)


class STARTUPINFOW(ctypes.Structure):
	_fields_ = [("cb", wt.DWORD), ("lpReserved", wt.LPWSTR), ("lpDesktop", wt.LPWSTR), ("lpTitle", wt.LPWSTR),
		("dwX", wt.DWORD), ("dwY", wt.DWORD), ("dwXSize", wt.DWORD), ("dwYSize", wt.DWORD),
		("dwXCountChars", wt.DWORD), ("dwYCountChars", wt.DWORD), ("dwFillAttribute", wt.DWORD),
		("dwFlags", wt.DWORD), ("wShowWindow", wt.WORD), ("cbReserved2", wt.WORD), ("lpReserved2", ctypes.c_void_p),
		("hStdInput", wt.HANDLE), ("hStdOutput", wt.HANDLE), ("hStdError", wt.HANDLE)]


class PROCESS_INFORMATION(ctypes.Structure):
	_fields_ = [("hProcess", wt.HANDLE), ("hThread", wt.HANDLE), ("dwProcessId", wt.DWORD), ("dwThreadId", wt.DWORD)]


u32.CreateDesktopW.restype = wt.HANDLE
u32.CreateDesktopW.argtypes = [wt.LPCWSTR, wt.LPCWSTR, ctypes.c_void_p, wt.DWORD, wt.DWORD, ctypes.c_void_p]
k32.CreateProcessW.argtypes = [wt.LPCWSTR, wt.LPWSTR, ctypes.c_void_p, ctypes.c_void_p, wt.BOOL, wt.DWORD,
	ctypes.c_void_p, wt.LPCWSTR, ctypes.POINTER(STARTUPINFOW), ctypes.POINTER(PROCESS_INFORMATION)]
k32.WaitForSingleObject.argtypes = [wt.HANDLE, wt.DWORD]
k32.GetExitCodeProcess.argtypes = [wt.HANDLE, ctypes.POINTER(wt.DWORD)]
k32.TerminateProcess.argtypes = [wt.HANDLE, wt.UINT]
k32.SetHandleInformation.argtypes = [wt.HANDLE, wt.DWORD, wt.DWORD]

_desk = None


def _desktop():
	global _desk
	if _desk is None:
		_desk = u32.CreateDesktopW(DESKTOP, None, None, 0, GENERIC_ALL, None)
		if not _desk:
			raise OSError("CreateDesktop failed: %d" % ctypes.get_last_error())
	return _desk


class Proc:
	"""Enough of subprocess.Popen for the tests' runners: wait, poll, kill, returncode, pid."""

	def __init__(self, pi):
		self._h = pi.hProcess
		self.pid = pi.dwProcessId
		self.returncode = None
		k32.CloseHandle(pi.hThread)

	def poll(self):
		if self.returncode is None and k32.WaitForSingleObject(self._h, 0) == 0:
			code = wt.DWORD()
			k32.GetExitCodeProcess(self._h, ctypes.byref(code))
			self.returncode = code.value
		return self.returncode

	def wait(self, timeout=None):
		ms = 0xFFFFFFFF if timeout is None else int(timeout * 1000)
		if k32.WaitForSingleObject(self._h, ms) != 0:
			raise subprocess.TimeoutExpired("hidden desktop", timeout)
		return self.poll()

	def kill(self):
		if self.poll() is None:
			k32.TerminateProcess(self._h, 1)
			self.wait(10)

	terminate = kill


def popen(args, stdout=None, stderr=None, env=None, cwd=None):
	_desktop()
	si = STARTUPINFOW()
	si.cb = ctypes.sizeof(si)
	si.lpDesktop = "WinSta0\\" + DESKTOP
	inherit = False
	if stdout is not None:
		import msvcrt
		h = msvcrt.get_osfhandle(stdout.fileno())
		k32.SetHandleInformation(h, HANDLE_FLAG_INHERIT, HANDLE_FLAG_INHERIT)
		herr = h if stderr in (None, subprocess.STDOUT) else msvcrt.get_osfhandle(stderr.fileno())
		k32.SetHandleInformation(herr, HANDLE_FLAG_INHERIT, HANDLE_FLAG_INHERIT)
		si.dwFlags |= STARTF_USESTDHANDLES
		si.hStdOutput = h
		si.hStdError = herr
		inherit = True
	block = None
	flags = 0
	if env is not None:
		block = ctypes.create_unicode_buffer("".join("%s=%s\0" % kv for kv in env.items()) + "\0")
		flags |= CREATE_UNICODE_ENVIRONMENT
	pi = PROCESS_INFORMATION()
	cmd = ctypes.create_unicode_buffer(subprocess.list2cmdline([str(a) for a in args]))
	if not k32.CreateProcessW(None, cmd, None, None, inherit, flags, block, cwd, ctypes.byref(si), ctypes.byref(pi)):
		raise OSError("CreateProcess failed: %d" % ctypes.get_last_error())
	return Proc(pi)


def main():
	argv = sys.argv[1:]
	log = None
	if "--log" in argv[: argv.index("--") if "--" in argv else len(argv)]:
		i = argv.index("--log")
		log = argv[i + 1]
		del argv[i:i + 2]
	if "--" in argv:
		argv = argv[argv.index("--") + 1:]
	out = open(log, "w", encoding="utf-8") if log else sys.stdout
	p = popen(argv, stdout=out, env=dict(os.environ))
	try:
		return p.wait()
	except KeyboardInterrupt:
		p.kill()
		return 1


if __name__ == "__main__":
	sys.exit(main())
