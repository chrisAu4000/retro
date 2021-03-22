module Model.Board exposing (..)

import Json.Decode as JsonDecode
import Json.Encode as JsonEncode
import Model.Lane exposing (Lane, laneDecoder, laneEncoder)


type alias Board =
    { id : String
    , name : String
    , lanes : List Lane
    }


boardEncoder : Board -> JsonEncode.Value
boardEncoder board =
    JsonEncode.object
        [ ( "_id", JsonEncode.string board.id )
        , ( "name", JsonEncode.string board.name )
        , ( "lanes", JsonEncode.list laneEncoder board.lanes )
        ]


boardDecoder : JsonDecode.Decoder Board
boardDecoder =
    JsonDecode.map3 Board
        (JsonDecode.at [ "_id" ] JsonDecode.string)
        (JsonDecode.at [ "name" ] JsonDecode.string)
        (JsonDecode.at [ "lanes" ] (JsonDecode.list laneDecoder))
