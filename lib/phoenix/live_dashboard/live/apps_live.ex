defmodule Phoenix.LiveDashboard.AppsLive do
  use Phoenix.LiveDashboard.Web, :live_view

  alias Phoenix.LiveDashboard.{
    SystemInfo,
    ProcessInfoComponent,
    ReingoldTilford,
    TreeDrawingHelpers
  }

  @temporary_assigns [
    nodes: [],
    lines: [],
    height: 500,
    width: 500,
    params: %{}
  ]

  @impl true
  def mount(%{"node" => _} = params, session, socket) do
    {:ok, assign_mount(socket, :apps, params, session, true), temporary_assigns: @temporary_assigns}
  end

  @impl true
  def handle_params(params, _url, socket) do
    socket =
      socket
      |> assign_params(params)
      |> fetch_started_applications()
      |> assign_application(params)
      |> fetch_nodes_and_lines()
      |> fetch_width_and_height()

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~L"""
      <div class="tabular-page applications_tab">
        <h5 class="card-title">Applications</h5>
        <h5><%= @application%></h5>
        <div class="row active_applications_list">
          <div class="col-sm-2 overflow">
            <ul class="list-group grouped_list_hover active_items">
              <%= for app <- @applications do %>
              <button type="button" class="list-group-item list-group-item-action" phx-click="select_app" phx-value-app="<%= app %>"><%= app %></button>
              <% end %>
            </ul
          </div>
        </div>
        <div class="card col-sm-10 application_tree overflow">
          <div style="width: 1000px; height: 1000px;">
            <svg width="<%= @width %>" height="<%= @height %>" id="tree" class="tree" >
                <%= for node <- @nodes, pid = encode_pid(node.pid) do %>
                <rect x="<%= node.x %>" y="<%= node.y %>" rx="20" ry="20" width="<%= node.width %>" height="<%= node.height %>"
                class="node"  phx-click="show_info" phx-value-pid="<%= pid %>" phx-page-loading />
                <text class="tree_node_text" x="<%= node.x + 5 %>" y="<%= node.y + node.height *0.6%>">
                <%= node.name %> </text>
                <% end %>
                #<%= for line <- @lines do %>
                <line x1="<%= line.x1 %>" y1="<%= line.y1 %>" x2="<%= line.x2 %>" y2="<%= line.y2 %>" class="line" />
                #<% end %>
            </svg>
          </div>
        </div>
      </div>
    """
  end

  @impl true
  def handle_info(:refresh, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("show_info", %{"pid" => pid}, socket) do
    params = Map.put(socket.assigns.params, :info, pid)
    {:noreply, push_redirect(socket, to: self_path(socket, node(), params))}
  end

  @impl true
  def handle_event("select_app", %{"app" => application}, socket) do
    params = Map.put(socket.assigns.params, :application, application)
    {:noreply, push_patch(socket, to: self_path(socket, node(), params))}
  end

  defp self_path(socket, node, params) do
    live_dashboard_path(socket, :apps, node, params)
  end

  defp fetch_started_applications(%{assigns: %{menu: menu}} = socket) do
    applications =
      menu.node
      |> SystemInfo.fetch_started_applications()
      |> Enum.filter(&alive?/1)

    assign(socket, applications: applications)
  end

  defp fetch_nodes_and_lines(%{assigns: %{application: application, menu: menu}} = socket) do
    tree =
      menu.node
      |> SystemInfo.fetch_app_tree(application)
      |> ReingoldTilford.set_layout_settings(&name_length/1)

    assign(socket,
      nodes: tree |> TreeDrawingHelpers.extract_nodes(),
      lines: tree |> TreeDrawingHelpers.extract_lines()
    )
  end

  defp fetch_width_and_height(%{assigns: %{nodes: nodes}} = socket) do
    {width, height} = TreeDrawingHelpers.svg_size(nodes)

    assign(socket, width: width, height: height)
  end



  defp assign_application(socket, params) do
    application =
    if Map.has_key?(params, "application") do
      String.to_atom(params["application"])
    else
      hd(socket.assigns.applications)
    end
    assign(socket, :application, application)
  end

  defp alive?(app) do
    app
    |> :application_controller.get_master()
    |> is_pid
  catch
    _, _ -> false
  end

  defp name_length({_, pid, name}) do
    name =
      if name == [] do
        pid |> inspect |> String.trim_leading("#PID")
      else
        inspect(name)
      end

    String.length(name) * 10
  end
end
