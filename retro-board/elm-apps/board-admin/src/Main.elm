port module Main exposing (..)

import Browser
import Browser.Dom as Dom exposing (Error)
import Html exposing (Html, a, button, div, form, h1, h3, h4, input, span, text, textarea)
import Html.Attributes exposing (attribute, class, id, readonly, style, title, type_, value)
import Html.Events exposing (onClick, onInput)
import Html5.DragDrop as DragDrop
import Http
import Json.Decode as JsonDecode
import Json.Encode as JsonEncode
import Model.Board exposing (Board, boardDecoder)
import Model.Lane exposing (Lane, LaneId)
import Model.Message exposing (Message, MessageId)
import Model.WebSocketMessage exposing (socketMessageEncoder)
import Task
import Url exposing (Url)


port setHeight : JsonEncode.Value -> Cmd msg


port copyToClipboard : () -> Cmd msg


port dragstart : JsonEncode.Value -> Cmd msg


port sendSocketMessage : JsonEncode.Value -> Cmd msg


port receiveSocketMessage : (JsonDecode.Value -> msg) -> Sub msg


type alias Model =
    { board : Maybe Board
    , boardId : Maybe String
    , dragDrop : DragDrop.Model LaneId LaneId
    , url : Maybe Url
    , error : Maybe String
    }


init : String -> ( Model, Cmd Msg )
init urlStr =
    let
        maybeUrl =
            Url.fromString urlStr

        request : String -> Cmd Msg
        request fragment =
            Http.get
                { url = "/board?board-id=" ++ fragment
                , expect = Http.expectJson FetchDataRequest boardDecoder
                }
    in
    ( { board = Nothing
      , boardId = Maybe.andThen .fragment maybeUrl
      , dragDrop = DragDrop.init
      , url = maybeUrl
      , error = Nothing
      }
    , maybeUrl
        |> Maybe.andThen .fragment
        |> Maybe.map request
        |> Maybe.withDefault Cmd.none
    )


main : Program String Model Msg
main =
    Browser.element
        { init = init
        , update = update
        , subscriptions = subscriptions
        , view = view
        }


subscriptions : a -> Sub Msg
subscriptions _ =
    receiveSocketMessage (OnSocket << JsonDecode.decodeValue boardDecoder)


type Msg
    = FetchDataRequest (Result Http.Error Board)
    | CopyToClipboard
    | CreateMessage Lane
    | DeleteMessage Lane Message
    | UpdateMessageText Lane Message String
    | UpdateTextareaHeight Message (Result Dom.Error Dom.Viewport)
    | UpdateMessageUpvotes Lane Message
    | DragDropMsg (DragDrop.Msg MessageId LaneId)
    | OnSocket (Result JsonDecode.Error Board)


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    let
        boardId =
            Maybe.map .id model.board
                |> Maybe.map JsonEncode.string
                |> Maybe.withDefault JsonEncode.null
    in
    case msg of
        CopyToClipboard ->
            ( model, copyToClipboard () )

        FetchDataRequest result ->
            case result of
                Result.Err e ->
                    handleError model "Cannot find retro"

                Result.Ok board ->
                    ( { model | board = Just board }, Cmd.none )

        CreateMessage lane ->
            JsonEncode.object
                [ ( "boardId", boardId )
                , ( "laneId", JsonEncode.string lane.id )
                ]
                |> socketMessageEncoder "create-message"
                |> sendSocketMessage
                |> Tuple.pair model

        DeleteMessage lane message ->
            JsonEncode.object
                [ ( "boardId", boardId )
                , ( "laneId", JsonEncode.string lane.id )
                , ( "messageId", JsonEncode.string message.id )
                ]
                |> socketMessageEncoder "delete-message"
                |> sendSocketMessage
                |> Tuple.pair model

        UpdateMessageText lane message text ->
            let
                viewport =
                    Dom.getViewportOf message.id
                        |> Task.attempt (UpdateTextareaHeight message)
            in
            JsonEncode.object
                [ ( "boardId", boardId )
                , ( "laneId", JsonEncode.string lane.id )
                , ( "messageId", JsonEncode.string message.id )
                , ( "text", JsonEncode.string text )
                ]
                |> socketMessageEncoder "update-message-text"
                |> sendSocketMessage
                |> Tuple.pair model

        UpdateTextareaHeight message result ->
            case result of
                Result.Err e ->
                    let
                        _ =
                            Debug.log "error" e
                    in
                    ( model, Cmd.none )

                Result.Ok viewport ->
                    let
                        _ =
                            Debug.log "viewport" viewport

                        _ =
                            Debug.log "scrollHeight" viewport.scene.height

                        val =
                            JsonEncode.object
                                [ ( "id", JsonEncode.string message.id )
                                , ( "value", JsonEncode.float viewport.scene.height )
                                ]
                    in
                    ( model, setHeight val )

        UpdateMessageUpvotes lane message ->
            JsonEncode.object
                [ ( "boardId", boardId )
                , ( "laneId", JsonEncode.string lane.id )
                , ( "messageId", JsonEncode.string message.id )
                ]
                |> socketMessageEncoder "update-message-upvote"
                |> sendSocketMessage
                |> Tuple.pair model

        DragDropMsg msg_ ->
            let
                ( model_, result ) =
                    DragDrop.update msg_ model.dragDrop

                next =
                    case result of
                        Just ( dragId, dropId, _ ) ->
                            { model | dragDrop = model_ }

                        Nothing ->
                            { model | dragDrop = model_ }
            in
            ( next
            , DragDrop.getDragstartEvent msg_
                |> Maybe.map (.event >> dragstart)
                |> Maybe.withDefault Cmd.none
            )

        OnSocket result ->
            case result of
                Err e ->
                    handleError model "Socket Error"

                Ok board ->
                    ( { model | board = Just board }, Cmd.none )


handleError : Model -> String -> ( Model, Cmd msg )
handleError model msg =
    ( { model | error = Just msg }, Cmd.none )


createError : String -> Html Msg
createError msg =
    div
        [ class "alert alert-danger" ]
        [ text msg ]


createMessage : Lane -> Message -> Html Msg
createMessage lane msg =
    div
        (class "card mb-2" :: DragDrop.draggable DragDropMsg msg.id)
        [ div
            [ class "d-flex justify-content-end" ]
            [ button
                [ onClick (DeleteMessage lane msg)
                , class "btn-close col-1 m-1"
                ]
                []
            ]
        , div
            [ class "form-group container my-1 px-2" ]
            [ div
                [ class "card-text" ]
                [ div
                    [ class "grow-wrap"
                    , attribute "data-replicated-value" (msg.text ++ " ")
                    ]
                    [ textarea
                        [ onInput (UpdateMessageText lane msg)
                        , id msg.id
                        , class "form-control"
                        , attribute "rows" "1"
                        , value msg.text
                        ]
                        []
                    ]
                ]
            ]
        , div
            [ class "d-flex justify-content-end" ]
            [ button
                [ onClick (UpdateMessageUpvotes lane msg)
                , class "btn btn-primary rounded-circle m-1"
                ]
                [ text (String.fromInt msg.upvotes) ]
            ]
        ]


createLane : Int -> Lane -> Html Msg
createLane n lane =
    div
        [ class "d-flex flex-column px-0"
        , style "flex" ("0 0" ++ String.fromInt (100 // n) ++ "%")
        ]
        [ div
            [ class "d-flex" ]
            [ h3
                [ class "lane__heading" ]
                [ button
                    [ onClick (CreateMessage lane)
                    , class "btn btn-outline-primary rounded-circle mx-2"
                    ]
                    [ text "+" ]
                , span
                    [ class "align-middle" ]
                    [ text lane.heading ]
                ]
            ]
        , div
            (class "d-flex flex-column p-1" :: DragDrop.droppable DragDropMsg lane.id)
            (List.map (createMessage lane) lane.messages)
        ]


createCopyLink : String -> Html Msg
createCopyLink url =
    form
        []
        [ div
            [ class "input-group" ]
            [ input
                [ class "form-control"
                , type_ "text"
                , id "copy"
                , value url
                , readonly True
                ]
                []
            , span
                [ onClick CopyToClipboard
                , class "input-group-btn"
                ]
                [ button
                    [ class "btn btn-outline-primary"
                    , style "border-bottom-left-radius" "0"
                    , style "border-top-left-radius" "0"
                    , type_ "button"
                    , title "Copy to Clipboard"
                    ]
                    [ text "Copy" ]
                ]
            ]
        ]


view : Model -> Html Msg
view model =
    div
        [ class "container retroboard" ]
        [ model.error
            |> Maybe.map createError
            |> Maybe.withDefault (div [] [])
        , case model.board of
            Nothing ->
                div [] []

            Just board ->
                let
                    dropId =
                        DragDrop.getDropId model.dragDrop

                    dragId =
                        DragDrop.getDragId model.dragDrop

                    host =
                        Maybe.map .host model.url
                            |> Maybe.withDefault ""

                    fragment =
                        Maybe.andThen .fragment model.url
                            |> Maybe.withDefault ""

                    publicUrl =
                        host ++ "/public/retro#" ++ fragment
                in
                div
                    []
                    [ h1
                        []
                        [ text board.name ]
                    , h4
                        []
                        [ text "Public Url:" ]
                    , createCopyLink publicUrl
                    , model.error
                        |> Maybe.map createError
                        |> Maybe.withDefault (div [] [])
                    , div
                        [ class "d-flex mt-3" ]
                        (List.map (createLane (List.length board.lanes)) board.lanes)
                    ]
        ]
