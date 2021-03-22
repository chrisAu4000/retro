module Model.Template exposing (..)

import Http
import Json.Decode as JsonDecode
import Json.Encode as JsonEncode
import Model.Lane exposing (Lane, laneDecoder, laneEncoder)


type alias Template =
    { id : Maybe String
    , name : Maybe String
    , lanes : List Lane
    }


emptyTemplate : Template
emptyTemplate =
    { id = Nothing, name = Nothing, lanes = [] }


templateEncoder : Template -> JsonEncode.Value
templateEncoder template =
    case ( template.id, template.name ) of
        ( Nothing, Nothing ) ->
            JsonEncode.object
                [ ( "lanes", JsonEncode.list laneEncoder template.lanes ) ]

        ( Just id, Nothing ) ->
            JsonEncode.object
                [ ( "id", JsonEncode.string id )
                , ( "lanes", JsonEncode.list laneEncoder template.lanes )
                ]

        ( Nothing, Just name ) ->
            JsonEncode.object
                [ ( "name", JsonEncode.string name )
                , ( "lanes", JsonEncode.list laneEncoder template.lanes )
                ]

        ( Just id, Just name ) ->
            JsonEncode.object
                [ ( "id", JsonEncode.string id )
                , ( "name", JsonEncode.string name )
                , ( "lanes", JsonEncode.list laneEncoder template.lanes )
                ]


templateDecoder : JsonDecode.Decoder Template
templateDecoder =
    JsonDecode.map3 Template
        (JsonDecode.field "_id" (JsonDecode.maybe JsonDecode.string))
        (JsonDecode.field "name" (JsonDecode.maybe JsonDecode.string))
        (JsonDecode.field "lanes" (JsonDecode.list laneDecoder))


getTemplate : String -> String -> (Result Http.Error Template -> msg) -> Cmd msg
getTemplate url hash msg =
    Http.get
        { url = url ++ "?id=" ++ hash
        , expect = Http.expectJson msg templateDecoder
        }


postTemplate : String -> Template -> (Result Http.Error Template -> msg) -> Cmd msg
postTemplate url template msg =
    Http.post
        { url = url
        , body = Http.jsonBody (templateEncoder template)
        , expect = Http.expectJson msg templateDecoder
        }


deleteTemplate : String -> Template -> (Result Http.Error () -> msg) -> Cmd msg
deleteTemplate url template msg =
    Http.post
        { url = url
        , body = Http.jsonBody (templateEncoder template)
        , expect = Http.expectWhatever msg
        }
