import QtQuick 2.9

Item {
    id: root

    property int size: 25
    property color color

    onColorChanged: {
        canvas.requestPaint();
    }

    property QtObject cornerEnum: QtObject {
        property int topLeft: 0
        property int topRight: 1
        property int bottomLeft: 2
        property int bottomRight: 3
    }

    property int corner: cornerEnum.topLeft // Default to TopLeft

    width: size
    height: size

    Canvas {
        id: canvas

        anchors.fill: parent
        antialiasing: true
        
        onPaint: {
            var ctx = getContext("2d");
            var r = root.size;

            // Clear previous contents to avoid compositing artifacts
            ctx.clearRect(0, 0, canvas.width, canvas.height);

            ctx.beginPath();
            switch (root.corner) {
                case cornerEnum.topLeft:
                    ctx.arc(r, r, r, Math.PI, 3 * Math.PI / 2);
                    ctx.lineTo(0, 0);
                    break;
                case cornerEnum.topRight:
                    ctx.arc(0, r, r, 3 * Math.PI / 2, 2 * Math.PI);
                    ctx.lineTo(r, 0);
                    break;
                case cornerEnum.bottomLeft:
                    ctx.arc(r, 0, r, Math.PI / 2, Math.PI);
                    ctx.lineTo(0, r);
                    break;
                case cornerEnum.bottomRight:
                    ctx.arc(0, 0, r, 0, Math.PI / 2);
                    ctx.lineTo(r, r);
                    break;
            }
            ctx.closePath();

            // Build an explicit rgba() color string from the QML color components so alpha is preserved
            var cr = Math.round(root.color.r * 255);
            var cg = Math.round(root.color.g * 255);
            var cb = Math.round(root.color.b * 255);
            var ca = root.color.a;
            ctx.fillStyle = "rgba(" + cr + "," + cg + "," + cb + "," + ca + ")";

            ctx.fill();
        }
    }

    Behavior on size {
        animation: Appearance?.animation.elementMoveFast.numberAnimation.createObject(this)
    }

}
