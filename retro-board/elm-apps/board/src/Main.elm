port module Main exposing (..)

import Browser
import Html exposing (Html, button, div, h1, h3, span, text, textarea)
import Html.Attributes exposing (attribute, class, disabled, readonly, style, value)
import Html.Events exposing (onClick, onInput)
import Http
import Json.Decode as JsonDecode
import Json.Encode as JsonEncode
import Model.ActionItem exposing (ActionItem)
import Model.Board exposing (Board, boardDecoder)
import Model.Lane exposing (Lane)
import Model.Message exposing (Message)
import Model.MessageStack exposing (MessageStack)
import Model.WebSocketMessage exposing (socketMessageEncoder)
import Url exposing (Url)


port sendSocketMessage : JsonEncode.Value -> Cmd msg


port receiveSocketMessage : (JsonDecode.Value -> msg) -> Sub msg


type Msg
    = FetchDataRequest (Result Http.Error Board)
    | CreateMessage Lane
    | DeleteMessage Lane MessageStack Message
    | UpdateMessageText Lane MessageStack Message String
    | UpdateMessageUpvotes Lane MessageStack Message
    | OnSocket (Result JsonDecode.Error Board)


type alias Model =
    { board : Maybe Board
    , boardId : Maybe String
    , url : Maybe Url
    , user : String
    , error : Maybe String
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
      }
    , maybeUrl
        |> Maybe.andThen .fragment
        |> Maybe.map request
        |> Maybe.withDefault Cmd.none
    )


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
            "btn-close col-1 m-1"
                ++ (if isCreater then
                        ""

                    else
                        " invisible"
                   )
    in
    div
        [ class "card mb-2" ]
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
                , class "btn btn-primary rounded-circle m-1"
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
        [ class "d-flex flex-column px-0"
        , style "flex" ("0 0" ++ String.fromInt (100 // columns) ++ "%")
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
            (List.map (createMessageStack userId lane) lane.stacks)
        ]


createError : String -> Html Msg
createError msg =
    div
        [ class "alert alert-danger my-5" ]
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
