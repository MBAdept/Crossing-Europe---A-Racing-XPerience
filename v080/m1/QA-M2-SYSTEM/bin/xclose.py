#!/usr/bin/env python3
"""Sends WM_DELETE_WINDOW to an X window (what a window manager's close button / Alt+F4 does).
Usage: DISPLAY=:N xclose.py <window id (decimal)>"""
import ctypes
import ctypes.util
import sys

X = ctypes.cdll.LoadLibrary(ctypes.util.find_library("X11"))
X.XOpenDisplay.restype = ctypes.c_void_p
X.XOpenDisplay.argtypes = [ctypes.c_char_p]
X.XInternAtom.restype = ctypes.c_ulong
X.XInternAtom.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_int]
X.XSendEvent.argtypes = [ctypes.c_void_p, ctypes.c_ulong, ctypes.c_int, ctypes.c_long, ctypes.c_void_p]
X.XFlush.argtypes = [ctypes.c_void_p]


class XClientMessageEvent(ctypes.Structure):
    _fields_ = [("type", ctypes.c_int), ("serial", ctypes.c_ulong), ("send_event", ctypes.c_int),
                ("display", ctypes.c_void_p), ("window", ctypes.c_ulong), ("message_type", ctypes.c_ulong),
                ("format", ctypes.c_int), ("data", ctypes.c_long * 5)]


class XEvent(ctypes.Union):
    _fields_ = [("xclient", XClientMessageEvent), ("pad", ctypes.c_long * 24)]


dpy = X.XOpenDisplay(None)
if not dpy:
    print("no display")
    sys.exit(2)
win = int(sys.argv[1])
ev = XEvent()
ev.xclient.type = 33  # ClientMessage
ev.xclient.window = win
ev.xclient.message_type = X.XInternAtom(dpy, b"WM_PROTOCOLS", 0)
ev.xclient.format = 32
ev.xclient.data[0] = X.XInternAtom(dpy, b"WM_DELETE_WINDOW", 0)
ev.xclient.data[1] = 0
ok = X.XSendEvent(dpy, win, 0, 0, ctypes.byref(ev))
X.XFlush(dpy)
print("sent", ok)
