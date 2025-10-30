import QtQuick
import qs
import qs.modules.common
import qs.modules.common.widgets

Item {
  id: root
  property int hour: (new Date()).getHours()
  property int minute: (new Date()).getMinutes()
  property bool is24h: DateTime.is24Hour
  property bool selectingHour: true
  property int minuteStep: 5
  property string timeString: pad2(hour) + ":" + pad2(minute)
  signal timeChanged(int hour, int minute)

  width: 320
  height: 420

  function pad2(n) { return (n < 10 ? "0" + n : "" + n) }
  function displayHour() {
    if (is24h) return pad2(hour)
    var h = hour % 12
    if (h === 0) h = 12
    return pad2(h)
  }
  function setHourFromDisplay(h) {
    if (is24h) {
      hour = Math.max(0, Math.min(23, h))
    } else {
      var isPM = hour >= 12
      var base = (h % 12) + (isPM ? 12 : 0)
      hour = Math.max(0, Math.min(23, base))
    }
    timeChanged(hour, minute)
  }
  function setMinute(m) {
    // No snapping to step for minutes for now; just to nearest minute
    var mm = Math.round(m)
    minute = Math.max(0, Math.min(59, mm))
    timeChanged(hour, minute)
  }

  function updateHandForCurrent() {
    var deg = 0
    if (selectingHour) {
      // Always align the hand to the 12-label ring positions so the visual
      // labels remain correct. For 24h we keep positions on the 12 ticks but
      // allow choosing either the base hour or base+12 depending on context.
      var disp = hour % 12
      if (disp === 0) disp = 12
      deg = disp * 30 - 90
    } else {
      deg = minute * 6 - 90
    }
    // Move hand using shortest arc; do not animate for state sync
    if (dialArea && dialArea.setHandAngle) {
      dialArea.setHandAngle(deg * Math.PI / 180, false)
    } else {
      hand.angleRad = deg * Math.PI / 180
    }
  }

//   StyledText {
//     text: "Select time"
//     color: Appearance.colors.colOnSurfaceVariant
//     anchors.left: parent.left
//     anchors.leftMargin: 8
//     anchors.top: parent.top
//     anchors.topMargin: 6
//     font.pixelSize: Appearance.font.pixelSize.title
//   }

  Row {
    id: fields
    spacing: 12
    anchors.top: parent.top
    anchors.topMargin: 28
    anchors.horizontalCenter: parent.horizontalCenter

    Rectangle {
      id: hourTile
      radius: 8
      color: selectingHour ? Appearance.colors.colPrimary : Appearance.m3colors.m3surfaceVariant
      border.width: 0
      width: 96
      height: 56
      MouseArea { anchors.fill: parent; onClicked: selectingHour = true; preventStealing: true }
      Behavior on color { ColorAnimation { duration: 140; easing.type: Easing.InOutQuad } }
      StyledText {
        anchors.centerIn: parent
        text: root.displayHour()
        color: selectingHour ? Appearance.colors.colOnPrimary : Appearance.colors.colOnSurface
        font.pixelSize: 28
        font.bold: true
      }
    }

    StyledText { text: ":"; color: Appearance.colors.colOnSurfaceVariant; anchors.verticalCenter: hourTile.verticalCenter; font.pixelSize: 24 }

    Rectangle {
      id: minuteTile
      radius: 8
      color: !selectingHour ? Appearance.colors.colPrimary : Appearance.m3colors.m3surfaceVariant
      border.width: 0
      width: 96
      height: 56
      MouseArea { anchors.fill: parent; onClicked: selectingHour = false; preventStealing: true }
      Behavior on color { ColorAnimation { duration: 140; easing.type: Easing.InOutQuad } }
      StyledText {
        anchors.centerIn: parent
        text: pad2(root.minute)
        color: !selectingHour ? Appearance.colors.colOnPrimary : Appearance.colors.colOnSurface
        font.pixelSize: 28
        font.bold: true
      }
    }

    // AM/PM segment (vertical joined pill with asymmetric corners and thick shared border)
    Item {
      id: ampmSegment
      visible: !is24h
      width: 64
      height: 96
      anchors.verticalCenter: hourTile.verticalCenter
      property color borderColor: Appearance.colors.colOutline
      property real borderWidth: 2

      // AM half
      Canvas {
        id: amCanvas
        anchors.top: parent.top
        anchors.left: parent.left
        width: parent.width
        height: parent.height / 2
        // keep always visible; fill/stroke indicate selection
        onPaint: {
          var ctx = getContext('2d')
          ctx.reset()
          ctx.lineCap = 'butt'
          ctx.lineJoin = 'miter'
          var rTop = 10
          var bw = ampmSegment.borderWidth
          var fill = (root.hour < 12) ? Appearance.colors.colPrimary : 'transparent'
          var stroke = (root.hour < 12) ? Appearance.colors.colPrimary : ampmSegment.borderColor
          // Fill path with rounded top corners only
          ctx.beginPath()
          ctx.moveTo(bw, height - bw)
          ctx.lineTo(bw, rTop)
          ctx.arcTo(bw, bw, rTop, bw, rTop - bw)
          ctx.lineTo(width - rTop, bw)
          ctx.arcTo(width - bw, bw, width - bw, rTop, rTop - bw)
          ctx.lineTo(width - bw, height - bw)
          ctx.closePath()
          ctx.fillStyle = fill
          ctx.fill()
          // Stroke only left, right and top edges (and bottom seam once)
          ctx.beginPath()
          ctx.moveTo(bw, height - bw)
          ctx.lineTo(bw, rTop)
          ctx.arcTo(bw, bw, rTop, bw, rTop - bw)
          ctx.lineTo(width - rTop, bw)
          ctx.arcTo(width - bw, bw, width - bw, rTop, rTop - bw)
          ctx.lineTo(width - bw, height - bw)
          ctx.strokeStyle = stroke
          ctx.lineWidth = bw
          ctx.stroke()
          // Bottom seam centered on the join: draw at half-line inside AM half
          ctx.beginPath()
          ctx.moveTo(bw, height - bw/2)
          ctx.lineTo(width - bw, height - bw/2)
          ctx.strokeStyle = ampmSegment.borderColor
          ctx.lineWidth = bw
          ctx.stroke()
        }
        MouseArea { anchors.fill: parent; preventStealing: true; onClicked: { if (root.hour >= 12) { root.hour -= 12; root.timeChanged(root.hour, root.minute); amCanvas.requestPaint(); pmCanvas.requestPaint() } } }
        Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.InOutQuad } }
        StyledText { anchors.centerIn: parent; text: 'AM'; font.bold: true; color: root.hour < 12 ? Appearance.colors.colOnPrimary : Appearance.colors.colOnSurface; Behavior on color { ColorAnimation { duration: 160; easing.type: Easing.InOutQuad } } }
      }

      // PM half
      Canvas {
        id: pmCanvas
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        width: parent.width
        height: parent.height / 2
        // keep always visible; fill/stroke indicate selection
        onPaint: {
          var ctx = getContext('2d')
          ctx.reset()
          ctx.lineCap = 'butt'
          ctx.lineJoin = 'miter'
          var rBot = 10
          var bw = ampmSegment.borderWidth
          var fill = (root.hour >= 12) ? Appearance.colors.colPrimary : 'transparent'
          var stroke = (root.hour >= 12) ? Appearance.colors.colPrimary : ampmSegment.borderColor
          // Fill path with rounded bottom corners only
          ctx.beginPath()
          ctx.moveTo(bw, 0)
          ctx.lineTo(width - bw, 0)
          ctx.lineTo(width - bw, height - rBot)
          ctx.arcTo(width - bw, height - bw, width - rBot, height - bw, rBot - bw)
          ctx.lineTo(rBot, height - bw)
          ctx.arcTo(bw, height - bw, bw, height - rBot, rBot - bw)
          ctx.lineTo(bw, 0)
          ctx.closePath()
          ctx.fillStyle = fill
          ctx.fill()
          // Stroke only left, right and bottom edges
          ctx.beginPath()
          ctx.moveTo(width - bw, 0)
          ctx.lineTo(width - bw, height - rBot)
          ctx.arcTo(width - bw, height - bw, width - rBot, height - bw, rBot - bw)
          ctx.lineTo(rBot, height - bw)
          ctx.arcTo(bw, height - bw, bw, height - rBot, rBot - bw)
          ctx.lineTo(bw, 0)
          ctx.strokeStyle = stroke
          ctx.lineWidth = bw
          ctx.stroke()
          // Top seam centered on the join: draw at half-line inside PM half
          ctx.beginPath()
          ctx.moveTo(bw, bw/2)
          ctx.lineTo(width - bw, bw/2)
          ctx.strokeStyle = ampmSegment.borderColor
          ctx.lineWidth = bw
          ctx.stroke()
        }
        MouseArea { anchors.fill: parent; preventStealing: true; onClicked: { if (root.hour < 12) { root.hour += 12; root.timeChanged(root.hour, root.minute); amCanvas.requestPaint(); pmCanvas.requestPaint() } } }
        Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.InOutQuad } }
        StyledText { anchors.centerIn: parent; text: 'PM'; font.bold: true; color: root.hour >= 12 ? Appearance.colors.colOnPrimary : Appearance.colors.colOnSurface; Behavior on color { ColorAnimation { duration: 160; easing.type: Easing.InOutQuad } } }
      }
    }
  }

  Item {
    id: dialArea
    anchors.top: fields.bottom
    anchors.topMargin: 16
    anchors.horizontalCenter: parent.horizontalCenter
    width: Math.min(parent.width - 32, 280)
    height: width

    property real centerX: width / 2
    property real centerY: height / 2
    property real radius: width / 2 - 16

    Rectangle {
      anchors.centerIn: parent
      width: dialArea.radius * 2
      height: dialArea.radius * 2
      radius: width / 2
      color: Appearance.m3colors.m3surfaceVariant
    }

    // Minute tick marks to help read minute position (visible in minute mode)
    Canvas {
      id: minuteTicks
      anchors.fill: parent
      visible: !root.selectingHour
      // keep below labels/knob by declaration order; no negative z
      onPaint: {
        var ctx = getContext('2d')
        ctx.reset()
        var cx = dialArea.centerX
        var cy = dialArea.centerY
        // Keep ticks outside the number ring (labels centered at radius-20 and extend out to ~radius-8)
        var rOuter = dialArea.radius - 2
        var rInnerMajor = rOuter - 6
        var rInnerMinor = rOuter - 4
        for (var i = 0; i < 60; i++) {
          var ang = (i * 6 - 90) * Math.PI / 180
          var r1 = (i % 5 === 0) ? rInnerMajor : rInnerMinor
          var x1 = cx + r1 * Math.cos(ang)
          var y1 = cy + r1 * Math.sin(ang)
          var x2 = cx + rOuter * Math.cos(ang)
          var y2 = cy + rOuter * Math.sin(ang)
          ctx.beginPath()
          ctx.moveTo(x1, y1)
          ctx.lineTo(x2, y2)
          ctx.strokeStyle = (i % 5 === 0) ? Appearance.colors.colOnSurface : Appearance.colors.colOnSurfaceVariant
          ctx.lineWidth = (i % 5 === 0) ? 2 : 1
          ctx.stroke()
        }
      }
    }

    // Hour tick marks to help read hour position (visible in hour mode)
    Canvas {
      id: hourTicks
      anchors.fill: parent
      visible: root.selectingHour
      onPaint: {
        var ctx = getContext('2d')
        ctx.reset()
        var cx = dialArea.centerX
        var cy = dialArea.centerY
        // Keep ticks outside the number ring as well
        var rOuter = dialArea.radius - 2
        var rInner = rOuter - 8
        for (var h = 0; h < 12; h++) {
          var ang = (h * 30 - 90) * Math.PI / 180
          var x1 = cx + rInner * Math.cos(ang)
          var y1 = cy + rInner * Math.sin(ang)
          var x2 = cx + rOuter * Math.cos(ang)
          var y2 = cy + rOuter * Math.sin(ang)
          ctx.beginPath()
          ctx.moveTo(x1, y1)
          ctx.lineTo(x2, y2)
          ctx.strokeStyle = Appearance.colors.colOnSurface
          ctx.lineWidth = 2
          ctx.stroke()
        }
      }
    }

    // Selected hour for highlight color
    readonly property int selectedHourDisplay: { var h = (root.hour % 12); return h === 0 ? 12 : h }
    // Hover targets used to highlight labels while moving the knob
    property int hoverHourDisplay: selectedHourDisplay
    property int hoverMinuteIndex: root.minute

    // Helper: choose nearest 24-hour candidate for a 12-hour display position
    function chooseClosest24(disp12, prevHour) {
      // disp12 is 1..12; map to 0..11 for candidateA (12->0)
      var a = disp12 % 12
      var b = a + 12
      // distance is simple absolute difference; this keeps continuity for small drags
      var da = Math.abs(prevHour - a)
      var db = Math.abs(prevHour - b)
      return (da <= db) ? a : b
    }

    // Smoothly set the hand angle using the shortest angular distance
    function setHandAngle(targetRad, animate) {
      hand.animEnabled = !!animate
      var prev = hand.angleRad
      var delta = Math.atan2(Math.sin(targetRad - prev), Math.cos(targetRad - prev))
      hand.angleRad = prev + delta
    }

    Repeater {
      model: 12
      delegate: Item {
        visible: root.selectingHour
        readonly property int index1: index + 1
        readonly property bool selected: root.selectingHour && index1 === dialArea.selectedHourDisplay
        readonly property bool hovered: root.selectingHour && index1 === dialArea.hoverHourDisplay
        width: 28; height: 28
        z: hovered ? 10 : (selected ? 3 : 0)
        x: dialArea.centerX + (dialArea.radius - 20) * Math.cos((index1 - 3) * Math.PI / 6) - width / 2
        y: dialArea.centerY + (dialArea.radius - 20) * Math.sin((index1 - 3) * Math.PI / 6) - height / 2
        Rectangle { anchors.fill: parent; radius: width/2; color: Appearance.colors.colPrimary; visible: false }
        StyledText {
          anchors.centerIn: parent
          text: index1
          // Only change when knob overlaps the label area
          color: (hovered && Math.abs(Math.atan2(Math.sin(hand.angleRad - ((index1*30-90)*Math.PI/180)), Math.cos(hand.angleRad - ((index1*30-90)*Math.PI/180)))) < (10 * Math.PI/180))
                 ? Appearance.colors.colOnPrimary : Appearance.colors.colOnSurface
          font.pixelSize: 14
          // keep static color to avoid double-circle look with knob
        }
      }
    }

    // Minute labels (every 5 minutes)
    Repeater {
      model: 60
      delegate: Item {
        readonly property int minuteIndex: index
        readonly property bool show: minuteIndex % root.minuteStep === 0
        readonly property bool selected: !root.selectingHour && minuteIndex === root.minute
        readonly property bool hovered: !root.selectingHour && minuteIndex === dialArea.hoverMinuteIndex
        visible: (!root.selectingHour && show)
        width: 24; height: 24
        z: hovered ? 10 : (selected ? 3 : 0)
        x: dialArea.centerX + (dialArea.radius - 20) * Math.cos((minuteIndex - 15) * Math.PI / 30) - width / 2
        y: dialArea.centerY + (dialArea.radius - 20) * Math.sin((minuteIndex - 15) * Math.PI / 30) - height / 2
        Rectangle { anchors.fill: parent; radius: width/2; color: Appearance.colors.colPrimary; visible: false }
        StyledText {
          anchors.centerIn: parent
          text: root.pad2(minuteIndex)
          // Only change when knob overlaps the label area
          color: (hovered && Math.abs(Math.atan2(Math.sin(hand.angleRad - ((minuteIndex*6-90)*Math.PI/180)), Math.cos(hand.angleRad - ((minuteIndex*6-90)*Math.PI/180)))) < (8 * Math.PI/180))
                 ? Appearance.colors.colOnPrimary : Appearance.colors.colOnSurface
          font.pixelSize: 12
          // keep static color to avoid double-circle look with knob
        }
      }
    }

    Item {
      id: hand
      anchors.fill: parent
      z: 5
      property real angleRad: 0
      property real length: dialArea.radius - 20
      property bool dragging: false
      // Toggleable animation for smooth moves
      property bool animEnabled: false
      Behavior on angleRad {
        enabled: hand.animEnabled
        NumberAnimation { duration: 180; easing.type: Easing.InOutQuad }
      }

      Canvas {
        id: handLine
        anchors.fill: parent
        antialiasing: true
        onPaint: {
          var ctx = getContext('2d')
          ctx.reset()
          ctx.lineCap = 'round'
          ctx.lineJoin = 'round'
          ctx.strokeStyle = Appearance.colors.colOnSurface
          ctx.lineWidth = 2
          
          var cx = dialArea.centerX
          var cy = dialArea.centerY
          var endX = cx + hand.length * Math.cos(hand.angleRad)
          var endY = cy + hand.length * Math.sin(hand.angleRad)
          
          ctx.beginPath()
          ctx.moveTo(cx, cy)
          ctx.lineTo(endX, endY)
          ctx.stroke()
        }
        Connections {
          target: hand
          function onAngleRadChanged() { handLine.requestPaint() }
        }
      }
      Rectangle {
        id: knob
        width: 36
        height: 36
        radius: 18
        color: Appearance.colors.colPrimary
        // Position bound to current angle; derived from dial center
        x: dialArea.centerX + hand.length * Math.cos(hand.angleRad) - width/2
        y: dialArea.centerY + hand.length * Math.sin(hand.angleRad) - height/2
        // Draggable joystick on the dial
        MouseArea {
          anchors.fill: parent
          preventStealing: true
          onPressed: function(mouse) {
            hand.dragging = true
            // animate hand to initial press position
            var p = knob.mapToItem(dialArea, mouse.x, mouse.y)
            var dx = p.x - dialArea.centerX
            var dy = p.y - dialArea.centerY
            var ang = Math.atan2(dy, dx)
            dialArea.setHandAngle(ang, true)
          }
          onReleased: {
            hand.dragging = false
            // Commit on release (hour snaps, minute no snap)
            var ang = hand.angleRad
            var deg = (ang * 180 / Math.PI)
            var twelveBased = (deg + 90 + 360) % 360
            if (selectingHour) {
              // Determine base 12-hour tick (1..12)
              var h12 = Math.round(twelveBased / 30) % 12
              if (h12 === 0) h12 = 12
              if (root.is24h) {
                // Choose nearest candidate (a or a+12) to maintain continuity
                var chosen = dialArea.chooseClosest24(h12, root.hour)
                root.hour = Math.max(0, Math.min(23, chosen))
                root.timeChanged(root.hour, root.minute)
                var snappedDeg = (h12 * 30)
                dialArea.setHandAngle((snappedDeg - 90) * Math.PI / 180, true)
                dialArea.hoverHourDisplay = dialArea.selectedHourDisplay
              } else {
                setHourFromDisplay(h12)
                var snappedDeg = (h12 * 30)
                dialArea.setHandAngle((snappedDeg - 90) * Math.PI / 180, true)
                dialArea.hoverHourDisplay = h12
              }
            } else {
                var mIndex = Math.round(twelveBased / 6) % 60
                setMinute(mIndex)
                // animate knob to exact minute position
                var snappedDegM = (mIndex * 6)
                dialArea.setHandAngle((snappedDegM - 90) * Math.PI / 180, true)
                dialArea.hoverMinuteIndex = mIndex
            }
          }
          onPositionChanged: function(mouse) {
            // map local mouse pos to dialArea coordinates
            var p = knob.mapToItem(dialArea, mouse.x, mouse.y)
            var dx = p.x - dialArea.centerX
            var dy = p.y - dialArea.centerY
            var len = Math.sqrt(dx*dx + dy*dy)
            if (len > 0) {
              var ang = Math.atan2(dy, dx)
              dialArea.setHandAngle(ang, false)
              var deg = (ang * 180 / Math.PI)
              var twelveBased = (deg + 90 + 360) % 360
              if (selectingHour) {
                // Use 12-tick detection for drag; in 24h choose nearest candidate
                var h12 = Math.round(twelveBased / 30) % 12
                if (h12 === 0) h12 = 12
                if (root.is24h) {
                  dialArea.hoverHourDisplay = ((h12 % 12) === 0) ? 12 : (h12 % 12)
                  var chosen = dialArea.chooseClosest24(h12, root.hour)
                  root.hour = Math.max(0, Math.min(23, chosen))
                  root.timeChanged(root.hour, root.minute)
                } else {
                  dialArea.hoverHourDisplay = h12
                  // update value live while dragging (suppress snap via onHourChanged gate)
                  setHourFromDisplay(h12)
                }
              } else {
                var mIndex = Math.round(twelveBased / 6) % 60
                dialArea.hoverMinuteIndex = mIndex
                // update value live while dragging (no snap for minutes)
                setMinute(mIndex)
              }
            }
          }
        }
      }
    }

    function trackFromPos(px, py) {
      var dx = px - dialArea.centerX
      var dy = py - dialArea.centerY
      var ang = Math.atan2(dy, dx)
      dialArea.setHandAngle(ang, false)
      var deg = (ang * 180 / Math.PI)
      var twelveBased = (deg + 90 + 360) % 360
      if (selectingHour) {
        var h12 = Math.round(twelveBased / 30) % 12
        if (h12 === 0) h12 = 12
        if (root.is24h) {
          dialArea.hoverHourDisplay = ((h12 % 12) === 0) ? 12 : (h12 % 12)
          var chosen = dialArea.chooseClosest24(h12, root.hour)
          root.hour = Math.max(0, Math.min(23, chosen))
          root.timeChanged(root.hour, root.minute)
        } else {
          dialArea.hoverHourDisplay = h12
          setHourFromDisplay(h12)
        }
      } else {
        var mIndex = Math.round(twelveBased / 6) % 60
        dialArea.hoverMinuteIndex = mIndex
        setMinute(mIndex)
      }
    }

    function commitFromCurrent() {
      var ang = hand.angleRad
      var deg = (ang * 180 / Math.PI)
      var twelveBased = (deg + 90 + 360) % 360
      if (selectingHour) {
        // Use 12-tick detection and map to nearest 24-hour candidate when needed
        var h12 = Math.round(twelveBased / 30) % 12
        if (h12 === 0) h12 = 12
        if (root.is24h) {
          var chosen = dialArea.chooseClosest24(h12, root.hour)
          root.hour = Math.max(0, Math.min(23, chosen))
          root.timeChanged(root.hour, root.minute)
          var snappedDeg = (h12 * 30)
          dialArea.setHandAngle((snappedDeg - 90) * Math.PI / 180, true)
          dialArea.hoverHourDisplay = dialArea.selectedHourDisplay
        } else {
          setHourFromDisplay(h12)
          var snappedDeg = (h12 * 30)
          dialArea.setHandAngle((snappedDeg - 90) * Math.PI / 180, true)
          dialArea.hoverHourDisplay = h12
        }
      } else {
        var mIndex = Math.round(twelveBased / 6) % 60
        setMinute(mIndex)
        var snappedDegM = (mIndex * 6)
        dialArea.setHandAngle((snappedDegM - 90) * Math.PI / 180, true)
        dialArea.hoverMinuteIndex = mIndex
      }
    }

    MouseArea {
      anchors.fill: parent
      preventStealing: true
      onPressed: function(mouse) {
        // Animate hand to initial click position, then track
        var dx = mouse.x - dialArea.centerX
        var dy = mouse.y - dialArea.centerY
        var ang = Math.atan2(dy, dx)
        dialArea.setHandAngle(ang, true)
        // update hover selection immediately
        var deg = (ang * 180 / Math.PI)
        var twelveBased = (deg + 90 + 360) % 360
        if (selectingHour) {
            var h12 = Math.round(twelveBased / 30) % 12
            if (h12 === 0) h12 = 12
            if (root.is24h) {
              dialArea.hoverHourDisplay = ((h12 % 12) === 0) ? 12 : (h12 % 12)
            } else {
              dialArea.hoverHourDisplay = h12
            }
        } else {
          var mIndex = Math.round(twelveBased / 6) % 60
          dialArea.hoverMinuteIndex = mIndex
        }
      }
      onPositionChanged: function(mouse) { if (pressed) dialArea.trackFromPos(mouse.x, mouse.y) }
      onReleased: dialArea.commitFromCurrent()
    }

    Component.onCompleted: updateHandForCurrent()
  }

  onSelectingHourChanged: {
    updateHandForCurrent()
    if (selectingHour) {
      dialArea.hoverHourDisplay = dialArea.selectedHourDisplay
    } else {
      dialArea.hoverMinuteIndex = root.minute
    }
  }
  onHourChanged: {
    if (!hand.dragging) {
      updateHandForCurrent()
    }
    if (!is24h) { amCanvas.requestPaint(); pmCanvas.requestPaint() }
    // Keep hover in sync so label color updates when time changes programmatically
    dialArea.hoverHourDisplay = dialArea.selectedHourDisplay
  }
  onMinuteChanged: {
    if (!hand.dragging) {
      updateHandForCurrent()
    }
    // Keep hover in sync for minute selection color
    if (!selectingHour) dialArea.hoverMinuteIndex = root.minute
  }
}


