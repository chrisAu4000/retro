module Controller.Message exposing (..)

import Model.Board exposing (Board)
import Model.Lane exposing (Lane, LaneId)
import Model.Message exposing (Message, MessageId)


deleteMessage : Maybe Board -> MessageId -> LaneId -> Maybe Board
deleteMessage maybeBoard messageId laneId =
    let
        removeMessage : Lane -> Lane
        removeMessage lane =
            { lane
                | messages = List.filter (\msg -> msg.id /= messageId) lane.messages
            }
    in
    maybeBoard
        |> Maybe.map .lanes
        |> Maybe.map
            (List.map
                (\lane ->
                    if lane.id == laneId then
                        removeMessage lane

                    else
                        lane
                )
            )
        |> Maybe.andThen (\lanes -> Maybe.map (\b -> { b | lanes = lanes }) maybeBoard)



-- addMessage : Maybe Board -> Message -> Maybe Board
-- addMessage maybeBoard message =
--     case maybeBoard of
--         Nothing ->
--             Nothing
--         Just board ->
--             let
--                 lanes =
--                     board.lanes
--                         |> List.map
--                             (\lane ->
--                                 if lane.id == message.laneId then
--                                     { lane | messages = lane.messages ++ [ message ] }
--                                 else
--                                     lane
--                             )
--             in
--             Just { board | lanes = lanes }


findLaneById : LaneId -> Board -> Maybe Lane
findLaneById laneId board =
    board.lanes
        |> List.filter (\lane -> lane.id == laneId)
        |> List.head


findMessageById : MessageId -> LaneId -> Board -> Maybe Message
findMessageById msgId laneId board =
    findLaneById laneId board
        |> Maybe.map (\lane -> List.filter (\msg -> msg.id == msgId) lane.messages)
        |> Maybe.andThen List.head


findAndMap : (Message -> Message) -> Message -> Lane -> Lane
findAndMap f message lane =
    { lane
        | messages =
            List.map
                (\msg ->
                    if msg.id == message.id then
                        f message

                    else
                        msg
                )
                lane.messages
    }


updateText : Message -> String -> Board -> Board
updateText message text board =
    let
        changeText =
            findAndMap (\msg -> { msg | text = text }) message
    in
    { board | lanes = List.map changeText board.lanes }


increaseUpvotes : Message -> Board -> Board
increaseUpvotes message board =
    let
        upvote =
            findAndMap (\msg -> { msg | upvotes = msg.upvotes + 1 }) message
    in
    { board | lanes = List.map upvote board.lanes }


decreaseUpvotes : Message -> Board -> Board
decreaseUpvotes message board =
    let
        downvote =
            findAndMap (\msg -> { msg | upvotes = msg.upvotes - 1 }) message
    in
    { board | lanes = List.map downvote board.lanes }
