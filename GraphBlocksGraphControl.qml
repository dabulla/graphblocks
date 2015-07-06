import QtQuick 2.0
import "qrc:/theme/";

Item {
    id: root
    z: -100

    property var input
    property var output

    property Component blockComponent: Qt.createComponent("GraphBlocksBlock.qml")
    property Component connectionComponent: Qt.createComponent("GraphBlocksConnection.qml")
    property int nextUniqueId: 0
    function clear() {
        for(var l= 0 ; l < parentForConnections.children.length ; ++l) {
            parentForConnections.children[l].destroy();
        }
        for(var i= 0 ; i < parentForBlocks.children.length ; ++i) {
            parentForBlocks.children[i].destroy();
        }
    }
    function saveGraph() {
        var objToSerialize = {blocks:[], connections:[]};
        for(var i= 0 ; i < parentForBlocks.children.length ; ++i) {
            var block = parentForBlocks.children[i];
            var serializedInner = block.inner.serialize?block.inner.serialize():{/*maybeTodo*/};
            var serializedBlock = {
                blockProto: {
                    x:block.x,
                    y:block.y,
                    displayName: block.displayName,
                    className: block.className?block.className:block.displayName,
                    uniqueId: block.uniqueId},
                innerProto: serializedInner};
            objToSerialize.blocks.push( serializedBlock );
        }
        for(var l= 0 ; l < parentForConnections.children.length ; ++l) {
            var connection = parentForConnections.children[l];
            var serializedConnection = {
                s1: connection.slot1.blockOuter.uniqueId,
                pn1: connection.slot1.propName,
                s1Inp: connection.slot1.isInput,
                s2: connection.slot2.blockOuter.uniqueId,
                pn2: connection.slot2.propName};
            objToSerialize.connections.push( serializedConnection );
        }
        //console.log(JSON.stringify( objToSerialize ));
        return objToSerialize;
    }
    Component {
        id: dynamicBlockInpCompo
        Item {
            property var output: ["outp"]
            property var outp
        }
    }
    Component {
        id: dynamicBlockOutpCompo
        Item {
            property var input: ["inp"]
            property var inp
        }
    }
    property real nextInY: 100
    property real nextOutY: 100
    function createDynamicInputBlock(setupInner) {
        createDynamicBlock(dynamicBlockInpCompo, {x: 100, y: nextInY}, setupInner);
        nextInY += 150;
    }
    function createDynamicOutputBlock(setupInner) {
        createDynamicBlock(dynamicBlockOutpCompo, {x: 800, y: nextOutY}, setupInner);
        nextOutY += 150;
    }
    function createDynamicBlock(dynamicBlockCompo, proto, setupInner) {
        var newBlock = root.blockComponent.createObject(parentForBlocks, proto);
        newBlock.uniqueId += nextUniqueId;
        nextUniqueId++;
        var newBlockInner = dynamicBlockCompo.createObject(newBlock.parentForInner, {});
        setupInner(newBlockInner);
        newBlock.inner = newBlockInner;
    }

    function loadGraph(obj, classMap, offset) {
        var startUniqueId = nextUniqueId;
        var blocks = obj.blocks;
        var connections = obj.connections;
        var savedUniqueIdToBlock = [];
        for(var i= 0 ; i < blocks.length ; ++i) {
            var serBlock = blocks[i];

            var newBlock = root.blockComponent.createObject(parentForBlocks, serBlock.blockProto);
            newBlock.uniqueId += startUniqueId;
            nextUniqueId = Math.max(nextUniqueId, newBlock.uniqueId);
            var compo = classMap[blocks[i].blockProto.className];
            if(!compo) {
                console.log("ERROR: graph could not be loaded due to unknown block type: \"" + blocks[i].blockProto.className + "\"");
                newBlock.inner = "ERROR";
            } else {
                var newBlockInner = compo.compo.createObject(newBlock.parentForInner, serBlock.innerProto);
                newBlock.inner = newBlockInner;
            }
            savedUniqueIdToBlock[serBlock.blockProto.uniqueId] = newBlock;
        }
        nextUniqueId++;
        for(var l= 0 ; l < connections.length ; ++l) {
            var connection = connections[l];
            var b1 = savedUniqueIdToBlock[connection.s1];
            var b2 = savedUniqueIdToBlock[connection.s2];
            var s1 = b1.getSlot(connection.pn1, connection.s1Inp);
            var s2 = b2.getSlot(connection.pn2, !connection.s1Inp);
            fullScreenMouseArea.createConnection(s1, s2);
        }
    }
    Component.onCompleted: {
        if( blockComponent.status != Component.Ready )
        {
            if( blockComponent.status == Component.Error )
                console.debug("Error: "+ blockComponent.errorString() );
        }
        if( connectionComponent.status != Component.Ready )
        {
            if( connectionComponent.status == Component.Error )
                console.debug("Error: "+ connectionComponent.errorString() );
        }
        for(var inputs in root.input) {
            createDynamicInputBlock(function(innerBlock) {
                var propName = root.input[inputs];
                var chSigNam = propName.charAt(0).toUpperCase();
                chSigNam += propName.substring(1);
                var theSignal = root["on"+chSigNam+"Changed"];
                theSignal.connect(function() { innerBlock.outp = root[propName];});
            });
        }
        for(var outputs in root.output) {
            createDynamicOutputBlock(function(innerBlock) {
                innerBlock.onInpChanged.connect(function() { root[root.output[outputs]] = innerBlock.inp; });
            });
        }
    }

    Flickable {
        id:flickable
        anchors.fill: parent
        contentHeight: zoomer.width*zoomer.myScale
        contentWidth: zoomer.height*zoomer.myScale
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickDeceleration: 99999.0
        rebound: Transition {
            NumberAnimation {
                properties: "x,y"
                duration: 0
            }
        }
        z:2
        Item {
            width: 5000
            height: 5000
            id: zoomer
            property alias myScale: zoomer.scale
            transformOrigin: Item.TopLeft
            Item {
                id: parentForBlocks
                anchors.fill: parent
                z:100
            }
            Item {
                id: parentForConnections
                property alias connectionsOwner: fullScreenMouseArea
                anchors.fill: parent
                z:5
            }
            Rectangle {
                anchors.fill: parent
                color: ColorTheme.backgroundColor
            }

            DropArea {
                id: dropArea
                anchors.fill: parent

                onDropped: {
                    if(! drop.source.myCompo) {
                        drop.accepted = false;
                        return;
                    }
                    var xy = parentForBlocks.mapFromItem(drop.source.parent, drop.source.x, drop.source.y);
                    var newBlock = root.blockComponent.createObject(parentForBlocks, {x: xy.x, y: xy.y, uniqueId:root.nextUniqueId});
                    root.nextUniqueId++;
                    var newBlockInner = drop.source.myCompo.createObject(newBlock.parentForInner, {});
                    newBlock.inner = newBlockInner;
                    newBlock.displayName = drop.source.text;
                    newBlock.className = drop.source.currentClassName;
                }
            }
            MouseArea {
                z:7
                id: fullScreenMouseArea
                preventStealing: true
                property var dragStartSlot: null
                property var connections
                Component.onCompleted: connections = {}
                anchors.fill: parent
                function getSlotAtMouse() {
                    var block = parentForBlocks.childAt(mouseX, mouseY);
                    if( block ) {
                        var mx = mouseX - block.x;
                        var my = mouseY - block.y;
                        var layout = block.childAt(mx, my);
                        if( layout ) {
                            mx -= layout.x;
                            my -= layout.y;
                            var slot = layout.childAt(mx, my);
                            if(slot && (slot.isInput || slot.isOutput)) {
                                return slot;
                            }
                        }
                    }
                    return null;
                }
                hoverEnabled: true
                onClicked: {
                    forceActiveFocus();
                    mouse.accepted = false;
                }
                onMouseXChanged: {
                    previewConnection.lineEnd = {x:mouseX, y:mouseY};
                    previewConnection.requestPaint();
                }
                onMouseYChanged:{
                    previewConnection.lineEnd = {x:mouseX, y:mouseY};
                    previewConnection.requestPaint();
                }
                onWheel: {
                    var oldScale = zoomer.myScale
                    var maxZoom = Math.max(flickable.width/zoomer.width, flickable.height/zoomer.height);
                    zoomer.myScale = Math.max(Math.min(zoomer.myScale + wheel.angleDelta.y*0.0005, 1.0), maxZoom);
                    flickable.contentX += (mouseX)*(zoomer.myScale-oldScale);
                    flickable.contentY += (mouseY)*(zoomer.myScale-oldScale);
                    flickable.returnToBounds();
                }

                onPressed: {
                    forceActiveFocus();
                    var slot = getSlotAtMouse();
                    if( slot ) {
                        dragStartSlot = slot;
                        var xy = fullScreenMouseArea.mapFromItem(slot, slot.width*0.5, slot.height*0.5);
                        previewConnection.lineStart = xy;
                    }
                    else
                    {
                        mouse.accepted = false;
                    }
                }
                onReleased: {
                    forceActiveFocus();
                    var slot = getSlotAtMouse();
                    if( slot && dragStartSlot) {
                        createConnection(dragStartSlot, slot);
                    }
                    dragStartSlot = null;
                }
                function createConnection(slot1, slot2) {
                    //can connect?
                    if(typeof slot1 === "undefined" || typeof slot2 === "undefined") {
                        return;
                    }
                    if(typeof slot1.parent === "undefined" || typeof slot2.parent === "undefined") {
                        return;
                    }
                    if(slot1.parent.parent === slot2.parent.parent) {
                        return;
                    }
                    if(!(slot1.isInput && slot2.isOutput || slot1.isOutput && slot2.isInput)) {
                        return;
                    }
                    var inp = slot1.isInput?slot1:slot2;
                    var outp = slot1.isOutput?slot1:slot2;
                    var typeIn = typeof inp.block[inp.propName];
                    var typeOut = typeof outp.block[outp.propName];
                    if(typeIn == "function" && typeOut !== "function" || typeIn !== "function" && typeOut == "function") {
                        return;
                    }
                    if(!connections[inp]) {
                        connections[inp] = {};
                    }
                    if(connections[inp][outp]) {
                        return;
                    }

                    if(typeIn == "function" && typeOut == "function") {
                        outp.block[outp.propName].connect(inp.block[inp.propName]);
                        // no initial call
                        //inp.block[inp.propName]();
                    } else {
                        //forbid multiple inputs?
                        Object.keys(connections[inp]).forEach(function(s2prop) {
                            // can have deleted connections
                            if(connections[inp].hasOwnProperty(s2prop)) {
                                if( connections[inp][s2prop] ) {
                                    connections[inp][s2prop].destroy();
                                }
                            }
                        });
                        connections[inp] = {};

                        var chSigNam = outp.propName.charAt(0).toUpperCase();
                        chSigNam += outp.propName.substring(1);
                        var theSignal = outp.block["on"+chSigNam+"Changed"];
                        // can occasionally cause an error when an event is fired while the signaltarget-block is deleted.
                        // no check is added here for performance
                        var fn;
                        if(inp.block.lazyConnect && (inp.block.lazyInputProps?inp.block.lazyInputProps.indexOf(inp.propName) !== -1:true)) {
                            var lazyInterval = inp.block.lazyInterval?inp.block.lazyInterval:1000
                            fn = function() {
                                console.log("lazy");
                                if(inp.lazyConnectTimer.running) {
                                    console.log("running tmr");
                                    return;
                                }
                                var timediff = Date.now() - inp.lazyConnectTimer.lastConnect;
                                if(timediff >= lazyInterval) {
                                    console.log("direct set possible");
                                    inp.block[inp.propName] = outp.block[outp.propName];
                                    inp.lazyConnectTimer.lastConnect = Date.now();
                                } else {
                                    console.log("setupDelay: " + (lazyInterval - timediff));
                                    inp.lazyConnectTimer.interval = lazyInterval - timediff;
                                    inp.lazyConnectTimer.start();
                                    inp.lazyConnectTimer.lastConnect -= 100; // ensure update will make it thru check next time
                                }
                            }
                            inp.lazyConnectTimer.onTriggered.connect(fn);
                        } else {
                            fn = function() { inp.block[inp.propName] = outp.block[outp.propName]; }
                        }
                        theSignal.connect( fn );
                        //initial set value
                        if(!outp.block.noInitialBind) {
                            fn();
                        }
                    }
                    var newConnection = root.connectionComponent.createObject(parentForConnections, {slot1: slot1, slot2: slot2, slotFunc: fn, startSignal: theSignal});
                    connections[inp][outp] = newConnection;
                    slot1.blockOuter.connections.push(newConnection);
                    slot2.blockOuter.connections.push(newConnection);
                }
            }
            GraphBlocksConnection {
                z: 1
                id: previewConnection
                visible: fullScreenMouseArea.dragStartSlot != null
            }
        }
    }
}
