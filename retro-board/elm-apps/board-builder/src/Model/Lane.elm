module Model.Lane exposing (..)

import Json.Decode as JsonDecode
import Json.Encode as JsonEncode


type alias LaneId =
    Maybe String


type alias Lane =
    { id : LaneId
    , heading : String
    }


laneEncoder : Lane -> JsonEncode.Value
laneEncoder lane =
    case lane.id of
        Nothing ->
            JsonEncode.object
                [ ( "heading", JsonEncode.string lane.heading ) ]

        Just id ->
            JsonEncode.object
                [ ( "_id", JsonEncode.string id )
                , ( "heading", JsonEncode.string lane.heading )
                ]


laneDecoder : JsonDecode.Decoder Lane
laneDecoder =
    JsonDecode.map2 Lane
        (JsonDecode.field "_id" (JsonDecode.maybe JsonDecode.string))
        (JsonDecode.field "heading" JsonDecode.string)
