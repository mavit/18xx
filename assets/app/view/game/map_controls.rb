# frozen_string_literal: true

require 'lib/settings'
require 'lib/storage'

module View
  module Game
    class MapControls < Snabberb::Component
      include Lib::Settings
      needs :show_coords, default: nil, store: true
      needs :show_location_names, default: true, store: true
      needs :show_starting_map, default: false, store: true
      needs :historical_routes, default: [], store: true
      needs :game, default: nil, store: true
      needs :show_player_colors, default: nil, store: true

      def render
        children = [
          player_colors_controls,
          location_names_controls,
          hex_coord_controls,
          starting_map_controls,
          route_controls,
        ].compact

        h(:div, children)
      end

      def player_colors_controls
        show_player_colors = Lib::Storage['show_player_colors']

        on_click = lambda do
          new_value = !show_player_colors
          Lib::Storage['show_player_colors'] = new_value
          store(:show_player_colors, new_value)
        end

        render_button("#{show_player_colors ? 'Hide' : 'Show'} Player Colors", on_click)
      end

      def location_names_controls
        show_hide = @show_location_names ? 'Hide' : 'Show'
        text = "#{show_hide} Location Names"

        on_click = lambda do
          new_value = !@show_location_names
          Lib::Storage['show_location_names'] = new_value
          store(:show_location_names, new_value)
        end

        render_button(text, on_click)
      end

      def hex_coord_controls
        show_hide = @show_coords ? 'Hide' : 'Show'
        text = "#{show_hide} Hex Coordinates"

        on_click = lambda do
          new_value = !@show_coords
          Lib::Storage['show_coords'] = new_value
          store(:show_coords, new_value)
        end

        render_button(text, on_click)
      end

      def starting_map_controls
        text = @show_starting_map ? 'Show Current Map' : 'Show Starting Map'

        on_click = lambda do
          store(:show_starting_map, !@show_starting_map)
        end

        render_button(text, on_click)
      end

      def generate_last_route(entity)
        operating = entity.operating_history
        last_run = operating[operating.keys.max]&.routes
        return [] unless last_run

        halts = operating[operating.keys.max]&.halts
        routes = []
        last_run.each do |train, connections|
          routes << Engine::Route.new(@game, @game.phase, train, connection_hexes: connections,
                                                                 routes: routes, num_halts: halts[train])
        end

        routes
      end

      def route_controls
        return unless @game

        step = @game.round.active_step
        actions = step&.actions(step&.current_entity) || []
        # Route controls are disabled during dividend and run routes step
        if (%w[run_routes dividend] & actions).any?
          store(:historical_routes, []) if @historical_routes.any?
          return
        end

        all_operators = @game.operated_operators
        operators = all_operators.map do |operator|
          revenue = operator.operating_history[operator.operating_history.keys.max].revenue
          attrs = { value: operator.name }
          h(:option, { attrs: attrs }, "#{operator.name} #{@game.format_currency(revenue)}")
        end

        attrs = {}
        operators.unshift(h(:option, { attrs: attrs }, 'None'))

        route_change = lambda do
          operator_name = Native(@route_input).elm&.value
          operator = all_operators.find { |o| o.name == operator_name }
          if operator
            store(:historical_routes, generate_last_route(operator))
          else
            store(:historical_routes, [])
          end
        end

        @route_input = render_select(id: :route, on: { input: route_change }, children: operators)
        h('label.inline-block', ['Show Last Route For:', @route_input])
      end

      def render_select(id:, on: {}, children: [])
        input_props = {
          attrs: {
            id: id,
          },
          on: { **on },
        }
        h(:select, input_props, children)
      end

      def render_button(text, action)
        props = {
          on: {
            click: action,
          },
        }

        h('button.small', props, text)
      end
    end
  end
end
