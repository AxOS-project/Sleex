import qs
import qs.modules.common
import qs.modules.common.functions
import qs.modules.lockscreen
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Scope {
	id: root
	LockContext {
		id: lockContext

		onUnlocked: {
			// Unlock the screen before exiting, or the compositor will display a
			// fallback lock you can't interact with.
			GlobalStates.screenLocked = false;
		}
	}

	WlSessionLock {
		id: lock
		locked: GlobalStates.screenLocked

		WlSessionLockSurface {
			color: "transparent"
			Loader {
                active: GlobalStates.screenLocked
                anchors.fill: parent
                opacity: active ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: 300
                        easing.type: Easing.InOutQuad
                    }
                }

                sourceComponent: LockSurface {
                    context: lockContext
                }
            }
		}
	}
}
