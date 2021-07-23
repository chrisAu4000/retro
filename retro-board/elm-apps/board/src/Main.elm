port module Main exposing (..)

import Browser
import Debounce exposing (Debounce)
import Html exposing (Html, button, div, h1, h3, span, text, textarea)
import Html.Attributes exposing (attribute, class, disabled, readonly, style, value)
import Html.Events exposing (onClick, onInput)
import Http
import Json.Decode as JsonDecode
import Json.Encode as JsonEncode
import Model.ActionItem exposing (ActionItem)
import Model.Board exposing (Board, boardDecoder)
import Model.Lane exposing (Lane, LaneId)
import Model.Message exposing (Message, MessageId)
import Model.MessageStack exposing (MessageStack, MessageStackId)
import Model.WebSocketMessage exposing (socketMessageEncoder)
import Url exposing (Url)


port sendSocketMessage : JsonEncode.Value -> Cmd msg


port receiveSocketMessage : (JsonDecode.Value -> msg) -> Sub msg


type Msg
    = FetchDataRequest (Result Http.Error Board)
    | CreateMessage Lane
    | DeleteMessage Lane MessageStack Message
    | UpdateMessageText Lane MessageStack Message String
    | DebounceMsg Debounce.Msg
    | UpdateMessageUpvotes Lane MessageStack Message
    | OnSocket (Result JsonDecode.Error Board)


type alias MessageChangeRequest =
    { laneId : LaneId
    , stackId : MessageStackId
    , messageId : MessageId
    , text : String
    }


type alias Model =
    { board : Maybe Board
    , boardId : Maybe String
    , url : Maybe Url
    , user : String
    , error : Maybe String
    , debounce : Debounce MessageChangeRequest
    }


type alias Flags =
    { href : String
    , user : String
    }


main : Program Flags Model Msg
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


init : Flags -> ( Model, Cmd Msg )
init flags =
    let
        { href, user } =
            flags

        maybeUrl =
            Url.fromString href

        request : String -> Cmd Msg
        request fragment =
            Http.get
                { url = "/board?board-id=" ++ fragment
                , expect = Http.expectJson FetchDataRequest boardDecoder
                }
    in
    ( { board = Nothing
      , boardId = Maybe.andThen .fragment maybeUrl
      , url = maybeUrl
      , user = user
      , error = Nothing
      , debounce = Debounce.init
      }
    , maybeUrl
        |> Maybe.andThen .fragment
        |> Maybe.map request
        |> Maybe.withDefault Cmd.none
    )


findAndMapStack : (MessageStack -> MessageStack) -> MessageStackId -> Lane -> Lane
findAndMapStack f stackId lane =
    { lane
        | stacks =
            List.map
                (\stk ->
                    if stk.id == stackId then
                        f stk

                    else
                        stk
                )
                lane.stacks
    }


findAndMapMessage : (Message -> Message) -> MessageId -> MessageStack -> MessageStack
findAndMapMessage f messageId stack =
    { stack
        | messages =
            List.map
                (\msg ->
                    if msg.id == messageId then
                        f msg

                    else
                        msg
                )
                stack.messages
    }


publishMessageChange : Maybe Board -> MessageChangeRequest -> Cmd Msg
publishMessageChange board req =
    board
        |> Maybe.map
            (\board_ ->
                JsonEncode.object
                    [ ( "boardId", JsonEncode.string board_.id )
                    , ( "laneId", JsonEncode.string req.laneId )
                    , ( "stackId", JsonEncode.string req.stackId )
                    , ( "messageId", JsonEncode.string req.messageId )
                    , ( "text", JsonEncode.string req.text )
                    ]
            )
        |> Maybe.map (socketMessageEncoder "update-message-text")
        |> Maybe.map sendSocketMessage
        |> Maybe.withDefault Cmd.none


updateMessageText : MessageStackId -> MessageId -> String -> Board -> Board
updateMessageText stackId msgId text board =
    let
        updateTxt : MessageStack -> MessageStack
        updateTxt =
            findAndMapMessage (\msg -> { msg | text = text }) msgId
    in
    { board | lanes = List.map (findAndMapStack updateTxt stackId) board.lanes }


debounceConfig : Debounce.Config Msg
debounceConfig =
    { strategy = Debounce.soonAfter 500 500
    , transform = DebounceMsg
    }


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    let
        boardId =
            Maybe.map .id model.board
                |> Maybe.map JsonEncode.string
                |> Maybe.withDefault JsonEncode.null
    in
    case msg of
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
            let
                updateTxt : Board -> Board
                updateTxt =
                    updateMessageText stack.id message.id text

                req =
                    { laneId = lane.id
                    , stackId = stack.id
                    , messageId = message.id
                    , text = text
                    }

                ( debounce, cmd ) =
                    Debounce.push debounceConfig req model.debounce
            in
            ( { model | board = Maybe.map updateTxt model.board, debounce = debounce }, cmd )

        DebounceMsg msg_ ->
            let
                ( debounce, cmd ) =
                    Debounce.update
                        debounceConfig
                        (Debounce.takeLast (publishMessageChange model.board))
                        msg_
                        model.debounce
            in
            ( { model | debounce = debounce }
            , cmd
            )

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

        OnSocket result ->
            case result of
                Err _ ->
                    handleError model "Socket error"

                Ok board ->
                    ( { model | board = Just board }, Cmd.none )


handleError : Model -> String -> ( Model, Cmd msg )
handleError model msg =
    ( { model | error = Just msg }, Cmd.none )


createMessage : String -> Lane -> MessageStack -> Message -> Html Msg
createMessage userId lane stack msg =
    let
        isCreater =
            userId == msg.createrId

        closeBtnClass =
            "delete-message btn-close col-1 m-1"
                ++ (if isCreater then
                        ""

                    else
                        " invisible"
                   )
    in
    div
        [ class "message card mb-2" ]
        [ if isCreater then
            div
                [ class "d-flex justify-content-end" ]
                [ button
                    [ onClick (DeleteMessage lane stack msg)
                    , class closeBtnClass
                    , disabled (not isCreater)
                    ]
                    []
                ]

          else
            text ""
        , div
            [ class "form-group container my-1 px-2" ]
            [ div
                [ class "card-text" ]
                [ if isCreater then
                    createOwnedMessageInput lane stack msg

                  else
                    createForeignMessageInput msg
                ]
            ]
        , div
            [ class "d-flex justify-content-end" ]
            [ button
                [ onClick (UpdateMessageUpvotes lane stack msg)
                , class "upvote btn btn-primary rounded-circle m-1"
                ]
                [ text (String.fromInt msg.upvotes) ]
            ]
        ]


createOwnedMessageInput : Lane -> MessageStack -> Message -> Html Msg
createOwnedMessageInput lane stack msg =
    div
        [ class "grow-wrap"
        , attribute "data-replicated-value" (msg.text ++ " ")
        ]
        [ textarea
            [ onInput (UpdateMessageText lane stack msg)
            , class "form-control"
            , attribute "rows" "1"
            , value msg.text
            ]
            []
        ]


createForeignMessageInput : Message -> Html Msg
createForeignMessageInput msg =
    div
        [ class "grow-wrap"
        , attribute "data-replicated-value" (msg.text ++ " ")
        ]
        [ textarea
            [ class "form-control foreign-message"
            , attribute "rows" "1"
            , value msg.text
            , readonly True
            ]
            []
        ]


createActionItem : ActionItem -> Html Msg
createActionItem action =
    div
        [ class "action-item card mb-2" ]
        [ div
            [ class "action-item-heading d-flex bd-highlight" ]
            [ div
                [ class "headline me-auto p-2 bd-highlight h4" ]
                [ text "Action:" ]
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
                        [ class "form-control"
                        , attribute "rows" "1"
                        , readonly True
                        , value action.text
                        ]
                        []
                    ]
                ]
            ]
        ]


createMessageStack : String -> Lane -> MessageStack -> Html Msg
createMessageStack userId lane stack =
    div
        [ class "message-stack rounded bg-light p-1 my-1" ]
        [ div
            [ class "message-list" ]
            (List.map (createMessage userId lane stack) stack.messages)
        , div
            [ class "action-items" ]
            (List.map createActionItem stack.actions)
        ]


createLane : String -> Int -> Lane -> Html Msg
createLane userId columns lane =
    div
        [ class "lane d-flex flex-column px-0"
        , style "flex" ("0 0" ++ String.fromInt (100 // columns) ++ "%")
        ]
        [ div
            [ class "d-flex" ]
            [ h3
                [ class "lane__heading" ]
                [ button
                    [ onClick (CreateMessage lane)
                    , class "add-message btn btn-outline-primary rounded mx-2"
                    ]
                    [ text "+" ]
                , span
                    [ class "align-middle" ]
                    [ text lane.heading ]
                ]
            ]
        , div
            [ class "d-flex flex-column p-1" ]
            (List.map (createMessageStack userId lane) lane.stacks)
        ]


createError : String -> Html Msg
createError msg =
    div
        [ class "error alert alert-danger my-5" ]
        [ text msg ]


view : Model -> Html Msg
view model =
    div
        [ class "container retroboard" ]
        [ case ( model.board, model.error ) of
            ( Nothing, Nothing ) ->
                div [] [ text "Loading ..." ]

            ( _, Just err ) ->
                createError err

            ( Just board, Nothing ) ->
                div
                    []
                    [ h1
                        []
                        [ text board.name ]
                    , div
                        [ class "d-flex mt-3" ]
                        (List.map (createLane model.user (List.length board.lanes)) board.lanes)
                    ]
        ]
