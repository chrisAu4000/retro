module Main exposing (..)

import Browser
import Browser.Navigation as Nav
import Html exposing (Html, button, div, input, li, text, ul)
import Html.Attributes exposing (class, disabled, placeholder, type_, value)
import Html.Events exposing (onClick, onInput)
import Http
import Json.Decode as JsonDecode
import Model.Lane exposing (Lane)
import Model.Template exposing (Template, deleteTemplate, emptyTemplate, getTemplate, postTemplate)


main : Program String Model Msg
main =
    Browser.element
        { init = init
        , update = update
        , subscriptions = subscriptions
        , view = view
        }


subscriptions : a -> Sub msg
subscriptions _ =
    Sub.none


type alias Model =
    { template : Template
    , errorMessage : Maybe String
    }


init : String -> ( Model, Cmd Msg )
init hash =
    ( { template = emptyTemplate
      , errorMessage = Nothing
      }
    , if hash == "" then
        Cmd.none

      else
        getTemplate "/template" hash InitRequest
    )


type Msg
    = InitRequest (Result Http.Error Template)
    | AddLane
    | RemoveLane Int
    | UpdateLaneName Int String
    | UpdateTemplateName String
    | Save Template
    | Update Template
    | SaveTemplateRequest (Result Http.Error Template)
    | Discard Template
    | DiscardTemplateRequest (Result Http.Error ())


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        InitRequest result ->
            case result of
                Result.Ok template ->
                    ( { model | template = template }
                    , Cmd.none
                    )

                Result.Err _ ->
                    ( { model | errorMessage = Just "Cannot find Template" }, Cmd.none )

        AddLane ->
            ( { model | template = addLane model.template (Lane Nothing "") }
            , Cmd.none
            )

        RemoveLane index ->
            ( { model | template = deleteLane index model.template }
            , Cmd.none
            )

        UpdateLaneName index value ->
            ( { model | template = updateLaneHeadline model.template index value }
            , Cmd.none
            )

        UpdateTemplateName name ->
            ( { model | template = updateBoardName name model.template }
            , Cmd.none
            )

        Save template ->
            ( model
            , postTemplate "/template-create" template SaveTemplateRequest
            )

        Update template ->
            ( model
            , postTemplate "/template-update" template SaveTemplateRequest
            )

        SaveTemplateRequest result ->
            case result of
                Result.Ok template ->
                    ( { model | template = template }, Nav.load "/dashboard" )

                Result.Err _ ->
                    ( { model | errorMessage = Just "Cannot save Template" }, Cmd.none )

        Discard template ->
            ( model
            , discardBoard "/template-delete" template
            )

        DiscardTemplateRequest result ->
            case result of
                Result.Ok _ ->
                    ( model, Nav.load "/dashboard" )

                Result.Err _ ->
                    ( { model | errorMessage = Just "Cannot delete Template" }, Cmd.none )


addLane : Template -> Lane -> Template
addLane template lane =
    { template | lanes = template.lanes ++ [ lane ] }


deleteLane : Int -> Template -> Template
deleteLane index template =
    let
        lanes =
            List.indexedMap Tuple.pair template.lanes
                |> List.filter (Tuple.first >> (/=) index)
                |> List.map Tuple.second
    in
    { template | lanes = lanes }


updateLaneHeadline : Template -> Int -> String -> Template
updateLaneHeadline template index text =
    { template | lanes = List.indexedMap (updateHeadingById text index) template.lanes }


updateBoardName : String -> Template -> Template
updateBoardName name board =
    { board | name = Just name }


mapSecond : List ( a, b ) -> List b
mapSecond =
    List.map Tuple.second


urlDecoder : JsonDecode.Decoder String
urlDecoder =
    JsonDecode.field "url" JsonDecode.string


discardBoard : String -> Template -> Cmd Msg
discardBoard url template =
    Maybe.map (\_ -> deleteTemplate url template DiscardTemplateRequest) template.id
        |> Maybe.withDefault (Nav.load "/dashboard")


updateHeadingById : String -> Int -> Int -> Lane -> Lane
updateHeadingById heading target index lane =
    if index == target then
        { lane | heading = heading }

    else
        lane


createLane : Int -> Lane -> Html Msg
createLane index lane =
    li
        [ class "list-group-item" ]
        [ div
            [ class "input-group retroboard__lane-dragable" ]
            [ input
                [ onInput (UpdateLaneName index)
                , value lane.heading
                , type_ "text"
                , class "form-control"
                ]
                []
            , button
                [ onClick (RemoveLane index)
                , type_ "button"
                , class "btn btn-outline-danger"
                ]
                [ text "Remove" ]
            ]
        ]


errorMessage : Maybe String -> Html Msg
errorMessage error =
    case error of
        Nothing ->
            text ""

        Just message ->
            div
                [ class "alert alert-danger" ]
                [ text message ]


saveButton : Model -> Html Msg
saveButton model =
    let
        isDisabled =
            List.length model.template.lanes < 2
    in
    case model.template.id of
        Nothing ->
            button
                [ onClick (Save model.template)
                , class "btn btn-outline-success col-2 mx-1"
                , disabled isDisabled
                ]
                [ text "Save" ]

        Just _ ->
            button
                [ onClick (Update model.template)
                , class "btn btn-outline-success col-2 mx-1"
                , disabled isDisabled
                ]
                [ text "Update" ]


deleteButton : Model -> Html Msg
deleteButton model =
    case model.template.id of
        Nothing ->
            text ""

        Just _ ->
            button
                [ onClick (Discard model.template)
                , class "btn btn-outline-danger col-2 mx-1"
                ]
                [ text "Delete" ]


addLaneButton : Html Msg
addLaneButton =
    button
        [ onClick AddLane
        , class "btn btn-outline-primary col-2"
        ]
        [ text "Add Lane" ]


view : Model -> Html Msg
view model =
    div [ class "container py-3 d-flex flex-column px-0" ]
        [ errorMessage model.errorMessage
        , div
            [ class "d-flex" ]
            [ addLaneButton
            , div
                [ class "col-10 ps-2" ]
                [ input
                    [ value (model.template.name |> Maybe.withDefault "")
                    , onInput UpdateTemplateName
                    , type_ "text"
                    , class "form-control"
                    , placeholder "Template name"
                    ]
                    []
                ]
            ]
        , div
            [ class "flex py-3" ]
            [ ul
                [ class "list-group" ]
                (List.indexedMap createLane model.template.lanes)
            ]
        , div
            [ class "d-flex justify-content-end" ]
            [ saveButton model
            , deleteButton model
            ]
        ]
