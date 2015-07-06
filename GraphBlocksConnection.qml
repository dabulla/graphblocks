import QtQuick 2.0
import "qrc:/theme/";

Canvas {
    id:canvas
    property var slot1
    property var slot2
    property var lineStart: slot1 ? parent.mapFromItem(slot1, slot1.width*0.5, slot1.height*0.5) : {}
    property var lineEnd: slot2 ? parent.mapFromItem(slot2, slot2.width*0.5, slot2.height*0.5) : {}
    property var slotFunc
    property var startSignal
    x: Math.min(lineStart.x, lineEnd.x)-2;
    y: Math.min(lineStart.y, lineEnd.y)-2;
    z: 1
    width: Math.abs(lineEnd.x-lineStart.x)+4;
    height: Math.abs(lineEnd.y-lineStart.y)+4;
    onXChanged: requestPaint()
    onYChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    property var _oldSlot1
    property var _oldSlot2
    onSlot1Changed: setupBinding1()
    onSlot2Changed: setupBinding2()
    Component.onDestruction: {
        var inp = slot1?slot1.isInput?slot1:slot2:slot2?slot2.isInput?slot2:null:null;
        var outp = slot1?slot1.isOutput?slot1:slot2:slot2?slot2.isOutput?slot2:null:null;
        if(outp && startSignal && slotFunc) {
            startSignal.disconnect( slotFunc );
        }
        if(slot1 && slot2) {
            delete parent.connectionsOwner.connections[inp][outp];
        } else {
            if(parent.connectionsOwner) {
                Object.keys(parent.connectionsOwner.connections).forEach(function(inp) {
                    Object.keys(parent.connectionsOwner.connections[inp]).forEach(function(outp) {
                        // can have deleted connections
                        if(parent.connectionsOwner.connections[inp].hasOwnProperty(outp)) {
                            if(parent.connectionsOwner.connections[inp][outp] === canvas) {
                                delete parent.connectionsOwner.connections[inp][outp];
                            }
                        }
                    })
                });
            }
        }
        if(slot1) {
            var index1 = slot1.blockOuter.connections.indexOf(canvas);
            if (index1 > -1) {
                slot1.blockOuter.connections.splice(index1, 1);
            }
            slot1.parent.parent.onXChanged.disconnect(redoStart);
            slot1.parent.parent.onYChanged.disconnect(redoStart);
        }
        if(slot2) {
            var index2 = slot2.blockOuter.connections.indexOf(canvas);
            if (index2 > -1) {
                slot2.blockOuter.connections.splice(index2, 1);
            }
            slot2.parent.parent.onXChanged.disconnect(redoEnd);
            slot2.parent.parent.onYChanged.disconnect(redoEnd);
        }
    }

    Keys.onPressed: {
        if (event.key === Qt.Key_Delete) {
            destroy(1000);
            event.accepted = true;
        }
    }

    function setupBinding1() {
        if(_oldSlot1) {
            _oldSlot1.parent.parent.onXChanged.disconnect(redoStart);
            _oldSlot1.parent.parent.onYChanged.disconnect(redoStart);
        }
        if(slot1) {
            slot1.parent.parent.onXChanged.connect(redoStart);
            slot1.parent.parent.onYChanged.connect(redoStart);
            _oldSlot1 = slot1;
        }
    }
    function setupBinding2() {
        if(_oldSlot2) {
            _oldSlot2.parent.parent.onXChanged.disconnect(redoEnd);
            _oldSlot2.parent.parent.onYChanged.disconnect(redoEnd);
        }
        if(slot2) {
            slot2.parent.parent.onXChanged.connect(redoEnd);
            slot2.parent.parent.onYChanged.connect(redoEnd);
            _oldSlot2 = slot2;
        }
    }

    function redoStart() {
        canvas.lineStart = getLineStart();
        requestPaint();
    }
    function redoEnd() {
        canvas.lineEnd = getLineEnd();
        requestPaint();
    }

    function getLineStart() {
        return slot1 ? parent.mapFromItem(slot1, slot1.width*0.5, slot1.height*0.5) : lineStart;
    }
    function getLineEnd() {
        return slot2 ? parent.mapFromItem(slot2, slot2.width*0.5, slot2.height*0.5) : lineEnd;
    }

    Component.onCompleted: {
        setupBinding1();
        setupBinding2();
    }
    onFocusChanged: requestPaint()

    onPaint: {
        var ctx = canvas.getContext('2d');
        ctx.clearRect(2, 2, width-4, height-4);
        if( focus ) {
            ctx.strokeStyle = ColorTheme.connectionColorHighlight;// 'rgba(255,0,0,255)';
        } else {
            ctx.strokeStyle = ColorTheme.connectionColor;// 'rgba(255,255,0,255)';
        }

        ctx.beginPath();
        ctx.moveTo(lineStart.x - x + 2, lineStart.y - y + 2);
        ctx.lineTo(lineEnd.x - x + 2, lineEnd.y - y + 2);
        ctx.closePath();
        ctx.stroke();
    }
    MouseArea {
        id: conMa
        anchors.fill: parent
        property bool isOver

        onClicked: {
            var sx = lineStart.x - canvas.x + 2;
            var sy = lineStart.y - canvas.y + 2;
            var ex = lineEnd.x - canvas.x + 2 - sx;
            var ey = lineEnd.y - canvas.y + 2 - sy;
            var mx = mouseX - sx;
            var my = mouseY - sy;
            var len = Math.sqrt(ex*ex + ey*ey);
            var nx = ex/len;
            var ny = ey/len;
            var dot = nx*mx+ny*my;
            var ox = nx*dot - mx;
            var oy = ny*dot - my;
            var d = Math.sqrt(ox*ox + oy*oy);
            isOver = d < 5.0;
            if(isOver) {
                parent.forceActiveFocus();
            }
        }
    }
}