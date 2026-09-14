import os
import time
from pathlib import Path

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

from PySide6.QtCore import (
    Q_ARG,
    Q_RETURN_ARG,
    QCoreApplication,
    QEvent,
    QMetaObject,
    Qt,
    QUrl,
)
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlComponent, QQmlEngine

APP = QGuiApplication.instance() or QGuiApplication([])
ROOT = Path(__file__).resolve().parents[1]


class Client:
    def __init__(self, url, key="", timeout_ms=1000):
        self.engine = QQmlEngine()
        self.component = QQmlComponent(
            self.engine, QUrl.fromLocalFile(str(ROOT / "Controller.qml"))
        )
        if self.component.isError():
            raise RuntimeError(
                "\n".join(error.toString() for error in self.component.errors())
            )
        self.object = self.component.create()
        if self.object is None:
            raise RuntimeError(
                "\n".join(error.toString() for error in self.component.errors())
            )
        for name, value in {
            "checkUpdates": False,
            "baseUrl": url,
            "apiKey": key,
            "requestTimeoutMs": timeout_ms,
            "pollSeconds": 3600,
        }.items():
            self.set(name, value)

    def set(self, name, value):
        if not self.object.setProperty(name, value):
            raise AssertionError(f"Unknown property: {name}")

    def get(self, name):
        value = self.object.property(name)
        return value.toVariant() if hasattr(value, "toVariant") else value

    def call(self, name, *args):
        if not QMetaObject.invokeMethod(
            self.object,
            name,
            Qt.DirectConnection,
            *(Q_ARG("QVariant", arg) for arg in args),
        ):
            raise AssertionError(f"Could not invoke {name}")

    def start(self):
        self.set("active", True)
        self.wait(lambda: self.get("online") or bool(self.get("error")))
        self.wait(lambda: not self.get("refreshing"))

    def result(self, name):
        return QMetaObject.invokeMethod(
            self.object, name, Qt.DirectConnection, Q_RETURN_ARG("QVariant")
        )

    def wait(self, predicate, timeout=15):
        until = time.monotonic() + timeout
        while time.monotonic() < until:
            APP.processEvents()
            if predicate():
                return
            time.sleep(0.01)
        raise AssertionError(
            f"QML client timed out: {self.get('error')} {self.get('actionError')}"
        )

    def close(self):
        self.set("active", False)
        self.object.deleteLater()
        QCoreApplication.sendPostedEvents(None, QEvent.DeferredDelete)
        self.engine.deleteLater()
        QCoreApplication.sendPostedEvents(None, QEvent.DeferredDelete)
