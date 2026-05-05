import QtQuick
import Sleex.Utils
import qs.services

Item {
    id: postItManager
    anchors.fill: parent
    z: 50

    ListModel {
        id: postItModel
        Component.onCompleted: {
            let notes = DesktopStateManager.getPostIts()
            for (let i = 0; i < notes.length; i++) {
                postItModel.append(notes[i])
            }
        }
    }

    function saveNotes() {
        let arr = []
        for(let i = 0; i < postItModel.count; i++) {
            let item = postItModel.get(i)
            arr.push({
                posX: item.posX,
                posY: item.posY,
                text: item.text
            })
        }
        DesktopStateManager.savePostIts(arr)
    }

    function createNote(spawnX, spawnY) {
        postItModel.append({
            "posX": spawnX, 
            "posY": spawnY, 
            "text": ""
        })
        saveNotes()
    }

    Repeater {
        model: postItModel
        delegate: PostItDelegate {
            required property real posX
            required property real posY
            required property string text
            required property int index
            
            x: posX
            y: posY
            noteText: text
            
            onDeleteRequested: {
                postItModel.remove(index)
                postItManager.saveNotes()
            }
            
            onPositionUpdated: (newX, newY) => {
                postItModel.setProperty(index, "posX", newX)
                postItModel.setProperty(index, "posY", newY)
                postItManager.saveNotes()
            }
            
            onTextUpdated: (newText) => {
                postItModel.setProperty(index, "text", newText)
                postItManager.saveNotes()
            }
        }
    }
}