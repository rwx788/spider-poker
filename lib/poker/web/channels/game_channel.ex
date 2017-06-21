defmodule Poker.Web.GameChannel do
  @moduledoc false
  use Phoenix.Channel
  alias Poker.Web.Game
  alias Poker.Projects
  alias Poker.Projects.Project
  alias Poker.Accounts.User
  alias Poker.Web.Presence

  intercept ["game_state"]

  def join("game:" <> project_name, _params, socket) do
    case socket.assigns.user do
      %User{} = user ->
        case Projects.get(project_name) do
          {:ok, %Project{id: proj_id}} ->
            if Projects.member?(proj_id, user.id) do
              send(self(), :after_join)
              {:ok, socket}
            else
              {:error, %{reason: "unauthorized"}}
            end

          _ ->
            {:error, %{reason: "not found"}}
        end
      _ ->
        {:error, %{reason: "unauthorized"}}
    end
  end

  def handle_info(:after_join, socket) do
    {:ok, game} = Game.for(socket)
    payload = Game.display_public(game)
    push(socket, "game_state", %{game: payload})

    push(socket, "presence_state", Presence.list(socket))
    {:ok, _} = Presence.track(socket, socket.assigns.user.id, %{
      online_at: inspect(System.system_time(:seconds))
    })

    {:noreply, socket}
  end

  def handle_in("message", %{"anonymous" => anonymous?, "body" => body}, socket) do
    user_id = if anonymous?, do: 0, else: socket.assigns.user.id

    message = %{
      user_id: user_id,
      body: body
    }

    broadcast! socket, "message", %{message: message}
    {:noreply, socket}
  end

  # Story selection

  def handle_in("select_story", story_id, socket) do
    user = socket.assigns.user
    {:ok, game} = Game.for(socket)

    if Game.manager?(game, user) do
      {:ok, game} = Game.select_story(game, story_id)
      broadcast!(socket, "game_state", game)
    end

    {:noreply, socket}
  end


  # Voting

  def handle_in("start_voting", _, socket) do
    user = socket.assigns.user
    {:ok, game} = Game.for(socket)

    if Game.manager?(game, user) do
      duration = 3 * 60 # TODO: not hardcode this time
      time_to_end = System.system_time(:seconds) + duration

      {:ok, game} = Game.start_voting(game, time_to_end)
      broadcast!(socket, "game_state", game)

      :timer.send_after(duration * 1000, self(), :stop_voting)
    end

    {:noreply, socket}
  end

  def handle_info(:stop_voting, socket) do
    {:ok, game} = Game.for(socket)

    {:ok, game} = Game.stop_voting(game)
    broadcast!(socket, "game_state", game)

    {:noreply, socket}
  end

  def handle_in("stop_voting", _, socket) do
    user = socket.assigns.user
    {:ok, game} = Game.for(socket)

    if Game.manager?(game, user) do
      {:ok, game} = Game.stop_voting(game)
      broadcast!(socket, "game_state", game)
    end

    {:noreply, socket}
  end

  def handle_in("set_vote", vote, socket) do
    user = socket.assigns.user
    {:ok, game} = Game.for(socket)

    {:ok, game} = Game.set_vote(game, user.id, vote)
    broadcast!(socket, "game_state", game)

    {:noreply, socket}
  end

  def handle_in("set_score", score, socket) do
    user = socket.assigns.user
    {:ok, game} = Game.for(socket)

    if Game.manager?(game, user) do
      {:ok, {story, game}} = Game.set_score(game, score)
      broadcast!(socket, "game_state", game)
      broadcast!(socket, "story_updated", %{"story" => story})
    end

    {:noreply, socket}
  end

  def handle_in("finish_game", _, socket) do
    user = socket.assigns.user
    {:ok, game} = Game.for(socket)

    if Game.manager?(game, user) do
      {:ok, game} = Game.finish(game)
      broadcast!(socket, "game_finished", game)
    end

    {:noreply, socket}
  end

  def handle_out("game_state", game, socket) do
    payload = Game.display_public(game)
    push(socket, "game_state", %{game: payload})
    {:noreply, socket}
  end
end
