port module Main exposing (..)

import Browser
import Html exposing (Html, button, div, form, h1, h3, h4, input, span, text, textarea)
import Html.Attributes exposing (attribute, class, id, readonly, style, title, type_, value)
import Html.Events exposing (onClick, onInput)
import Html5.DragDrop as DragDrop
import Http
import Json.Decode as JsonDecode
import Json.Encode as JsonEncode
import Model.Board exposing (Board, boardDecoder)
import Model.Lane exposing (Lane, LaneId)
import Model.Message exposing (ActionItem, Message, MessageId, MessageStack, MessageStackId)
import Model.WebSocketMessage exposing (socketMessageEncoder)
import Url exposing (Url)


port copyToClipboard : () -> Cmd msg


port dragstart : JsonEncode.Value -> Cmd msg


port sendSocketMessage : JsonEncode.Value -> Cmd msg


port receiveSocketMessage : (JsonDecode.Value -> msg) -> Sub msg


type DroppableId
    = Stack MessageStackId
    | DropZone LaneId


type alias Model =
    { board : Maybe Board
    , boardId : Maybe String
    , dragDrop : DragDrop.Model ( LaneId, MessageStackId, MessageId ) ( LaneId, DroppableId )
    , hoveredStack : Maybe DroppableId
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
      , hoveredStack = Nothing
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
    | DeleteMessage Lane MessageStack Message
    | UpdateMessageText Lane MessageStack Message String
    | UpdateMessageUpvotes Lane MessageStack Message
    | DragDropMsg (DragDrop.Msg ( LaneId, MessageStackId, MessageId ) ( LaneId, DroppableId ))
    | CreateActionItem Lane MessageStack
    | DeleteActionItem Lane MessageStack ActionItem
    | UpdateActionItemText Lane MessageStack ActionItem String
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
                Result.Err _ ->
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

        DeleteMessage lane stack message ->
            JsonEncode.object
                [ ( "boardId", boardId )
                , ( "laneId", JsonEncode.string lane.id )
                , ( "stackId", JsonEncode.string stack.id )
                , ( "messageId", JsonEncode.string message.id )
                ]
                |> socketMessageEncoder "delete-message"
                |> sendSocketMessage
                |> Tuple.pair model

        UpdateMessageText lane stack message text ->
            JsonEncode.object
                [ ( "boardId", boardId )
                , ( "laneId", JsonEncode.string lane.id )
                , ( "stackId", JsonEncode.string stack.id )
                , ( "messageId", JsonEncode.string message.id )
                , ( "text", JsonEncode.string text )
                ]
                |> socketMessageEncoder "update-message-text"
                |> sendSocketMessage
                |> Tuple.pair model

        UpdateMessageUpvotes lane stack message ->
            JsonEncode.object
                [ ( "boardId", boardId )
                , ( "laneId", JsonEncode.string lane.id )
                , ( "stackId", JsonEncode.string stack.id )
                , ( "messageId", JsonEncode.string message.id )
                ]
                |> socketMessageEncoder "update-message-upvote"
                |> sendSocketMessage
                |> Tuple.pair model

        DragDropMsg msg_ ->
            let
                ( model_, result ) =
                    DragDrop.update msg_ model.dragDrop

                dropId_ =
                    DragDrop.getDropId model_
                        |> Maybe.map Tuple.second
            in
            case result of
                Just ( ( childLaneId, childStackId, dragId ), ( parentLaneId, droppableId ), _ ) ->
                    case droppableId of
                        Stack dropId ->
                            if childStackId == dropId then
                                ( { model | dragDrop = model_, hoveredStack = Nothing }, Cmd.none )

                            else
                                JsonEncode.object
                                    [ ( "boardId", boardId )
                                    , ( "childLaneId", JsonEncode.string childLaneId )
                                    , ( "parentLaneId", JsonEncode.string parentLaneId )
                                    , ( "childStackId", JsonEncode.string childStackId )
                                    , ( "parentStackId", JsonEncode.string dropId )
                                    , ( "childMessageId", JsonEncode.string dragId )
                                    ]
                                    |> socketMessageEncoder "merge-message"
                                    |> sendSocketMessage
                                    |> Tuple.pair { model | dragDrop = model_, hoveredStack = Nothing }

                        DropZone laneId ->
                            JsonEncode.object
                                [ ( "boardId", boardId )
                                , ( "childLaneId", JsonEncode.string childLaneId )
                                , ( "childStackId", JsonEncode.string childStackId )
                                , ( "childMessageId", JsonEncode.string dragId )
                                , ( "parentLaneId", JsonEncode.string laneId )
                                ]
                                |> socketMessageEncoder "split-message-stack"
                                |> sendSocketMessage
                                |> Tuple.pair { model | dragDrop = model_, hoveredStack = Nothing }

                Nothing ->
                    ( { model | dragDrop = model_, hoveredStack = dropId_ }, Cmd.none )

        CreateActionItem lane stack ->
            JsonEncode.object
                [ ( "boardId", boardId )
                , ( "laneId", JsonEncode.string lane.id )
                , ( "stackId", JsonEncode.string stack.id )
                ]
                |> socketMessageEncoder "create-action-item"
                |> sendSocketMessage
                |> Tuple.pair model

        DeleteActionItem lane stack action ->
            JsonEncode.object
                [ ( "boardId", boardId )
                , ( "laneId", JsonEncode.string lane.id )
                , ( "stackId", JsonEncode.string stack.id )
                , ( "actionId", JsonEncode.string action.id )
                ]
                |> socketMessageEncoder "delete-action-item"
                |> sendSocketMessage
                |> Tuple.pair model

        UpdateActionItemText lane stack action text ->
            JsonEncode.object
                [ ( "boardId", boardId )
                , ( "laneId", JsonEncode.string lane.id )
                , ( "stackId", JsonEncode.string stack.id )
                , ( "actionId", JsonEncode.string action.id )
                , ( "text", JsonEncode.string text )
                ]
                |> socketMessageEncoder "update-action-text"
                |> sendSocketMessage
                |> Tuple.pair model

        OnSocket result ->
            case result of
                Err _ ->
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


createMessage : Lane -> MessageStack -> Message -> Html Msg
createMessage lane stack msg =
    div
        (class "card mb-2" :: DragDrop.draggable DragDropMsg ( lane.id, stack.id, msg.id ))
        [ div
            [ class "d-flex justify-content-end" ]
            [ button
                [ onClick (DeleteMessage lane stack msg)
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
                        [ onInput (UpdateMessageText lane stack msg)
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
                [ onClick (UpdateMessageUpvotes lane stack msg)
                , class "btn btn-primary rounded-circle m-1"
                ]
                [ text (String.fromInt msg.upvotes) ]
            ]
        ]


createActionItem : Lane -> MessageStack -> ActionItem -> Html Msg
createActionItem lane stack action =
    div
        [ class "action-item card mb-2" ]
        [ div
            [ class "action-item-heading d-flex bd-highlight" ]
            [ div
                [ class "headline me-auto p-2 bd-highlight h4" ]
                [ text "Action:" ]
            , div
                [ class "d-flex justify-content-end" ]
                [ button
                    [ onClick (DeleteActionItem lane stack action)
                    , class "btn-close col-1 m-1"
                    ]
                    []
                ]
            ]
        , div
            [ class "form-group container my-1 px-2" ]
            [ div
                [ class "card-text" ]
                [ div
                    [ class "grow-wrap"
                    , attribute "data-replicated-value" (action.text ++ " ")
                    ]
                    [ textarea
                        [ onInput (UpdateActionItemText lane stack action)
                        , id action.id
                        , class "form-control"
                        , attribute "rows" "1"
                        , value action.text
                        ]
                        []
                    ]
                ]
            ]
        ]


createMessageStack : Lane -> Model -> MessageStack -> Html Msg
createMessageStack lane model stack =
    let
        normal =
            "message-stack rounded bg-light p-1 my-1"

        hovered =
            "message-stack border border-primary rounded bg-light p-1 my-1"

        class_ =
            case model.hoveredStack of
                Nothing ->
                    normal

                Just droppableId ->
                    case droppableId of
                        Stack stackId ->
                            if stackId == stack.id then
                                hovered

                            else
                                normal

                        DropZone _ ->
                            normal
    in
    div
        (class class_ :: DragDrop.droppable DragDropMsg ( lane.id, Stack stack.id ))
        [ div
            [ class "message-list" ]
            (List.map (createMessage lane stack) stack.messages)
        , div
            [ class "d-flex justify-content-end" ]
            [ button
                [ onClick (CreateActionItem lane stack)
                , class "btn btn-outline-success rounded"
                ]
                [ text "Action Item" ]
            ]
        , div
            [ class "action-items" ]
            (List.map (createActionItem lane stack) stack.actions)
        ]


createLane : Int -> Model -> Lane -> Html Msg
createLane n model lane =
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
                    , class "btn btn-outline-primary rounded mx-2"
                    ]
                    [ text "+" ]
                , span
                    [ class "align-middle" ]
                    [ text lane.heading ]
                ]
            ]
        , div
            [ class "d-flex flex-column p-1" ]
            (List.map (createMessageStack lane model) lane.stacks)
        , createDropZone lane.id model
        ]


createDropZone : LaneId -> Model -> Html Msg
createDropZone laneId model =
    let
        normal =
            div
                (class "drop-zone boarder-0 rounded m-1" :: DragDrop.droppable DragDropMsg ( laneId, DropZone laneId ))
                []

        hovered =
            div
                (class "drop-zone border border-primary rounded m-1" :: DragDrop.droppable DragDropMsg ( laneId, DropZone laneId ))
                []
    in
    case model.hoveredStack of
        Just droppableId ->
            case droppableId of
                Stack _ ->
                    normal

                DropZone laneId_ ->
                    if laneId_ == laneId then
                        hovered

                    else
                        normal

        Nothing ->
            normal


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
                    , div
                        [ class "d-flex mt-3" ]
                        (List.map (createLane (List.length board.lanes) model) board.lanes)
                    ]
        ]
