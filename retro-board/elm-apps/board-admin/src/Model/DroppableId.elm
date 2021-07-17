module Model.DroppableId exposing (..)

import Model.Lane exposing (LaneId)
import Model.MessageStack exposing (MessageStackId)


type DroppableId
    = Stack MessageStackId
    | DropZone LaneId
