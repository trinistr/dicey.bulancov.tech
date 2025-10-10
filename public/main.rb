require "observer"

require "js"
require "js/require_remote"

JS::RequireRemote.instance.load("dicey.pack.rb")
JS::RequireRemote.instance.load("vector_number.pack.rb")

DOCUMENT = JS.global[:document]
WINDOW = JS.global[:window]

module RAX
  class << self
    def call(tag, **properties, &children)
      node = DOCUMENT.createElement(tag)
      assign_properties(node, properties)
      add_children(node, children.call) if block_given?
      node
    end

    private

    def assign_properties(node, properties)
      properties.each_pair do |key, value|
        if key.start_with?("data-")
          node[:dataset][key[5..]] = value
        elsif key == :class
          node[:className] = value
        else
          node[kebab_camel(key)] = value
        end
      end
    end

    def add_children(node, children)
      children = [children] unless children.is_a?(Array)
      children.each do |child|
        child = JS.global[:Text].new(child.to_s) unless child.is_a?(JS::Object)
        node.appendChild(child)
      end
    end

    def kebab_camel(str)
      parts = str.to_s.split("-")
      return parts.first if parts.size == 1

      parts[1..].each { |part| part[0] = part[0].upcase }
      parts.join
    end
  end
end

module DiceSelection
  FOUNDRY = Dicey::DieFoundry.new

  class << self
    include Observable

    def add_dice(*values)
      values.each do |value|
        value = value.to_s.strip
        return false if value.empty?

        new_dice = Array(FOUNDRY.call(value))
        chips = new_dice.map { |die| build_die_chip(die) }
        selected_dice_list.append(*chips)
      rescue Dicey::DiceyError
        next
      end
      notify_observers(dice)
    end

    def remove_die(node)
      node.remove
      notify_observers(dice)
      node
    end

    def clear_dice
      selected_dice_list.replaceChildren
      notify_observers(dice)
    end

    def dice
      selected_dice_list[:children].to_a.map { |chip| FOUNDRY.call(chip[:dataset][:die].to_s) }
    end

    private

    def selected_dice_list
      DOCUMENT.getElementById("selected-dice-list")
    end

    def build_die_chip(die)
      name = die.to_s
      chip =
        RAX.("div", class: "dice-chip", "data-die": name) do
          [
            name,
            RAX.("button", class: "remove-button", "aria-label": "Remove") { "×" },
          ]
        end
      add_remove_listener_to_chip(chip)
      chip
    end

    def add_remove_listener_to_chip(chip)
      chip.querySelector("button").addEventListener("click") { remove_die(chip) }
    end

    def notify_observers(...)
      changed
      super
    end
  end
end

module RollController
  class << self
    def replace_roll(dice)
      self.current_dice = dice
      roll_output.replaceChildren and return if dice.empty?

      current_dice.each(&:roll)
      roll_output.replaceChildren(*build_full_roll_nodes)
      set_total(current_dice.map(&:current))
    end

    def reroll
      return if no_dice_selected?

      rolls = current_dice.map(&:roll)
      rolls.each_with_index { |roll, index| set_roll_at(index, roll) }
      set_total(rolls)
    end

    def reroll_die(index)
      return if no_dice_selected?

      roll = current_dice[index].roll
      set_roll_at(index, roll)
      set_total(current_dice.map(&:current))
    end

    private

    attr_accessor :current_dice

    def roll_output
      DOCUMENT.getElementById("roll-output")
    end

    def no_dice_selected?
      !current_dice || current_dice.empty?
    end

    def build_full_roll_nodes
      results = current_dice.map { |die| build_die_roll(die.to_s, die.current) }
      results.each_with_index do |node, index|
        node.addEventListener("click") { reroll_die(index) }
      end
      results << build_roll_total_node
      results
    end

    def build_die_roll(die, roll)
      RAX.("button", class: "standout-button die-roll-container") do
        [
          RAX.("div", class: "die-description", "data-die": die) { die },
          RAX.("div", class: "die-roll") { roll }
        ]
      end
    end

    def build_roll_total_node
      RAX.("div", id: "roll-total", class: "roll-total")
    end

    def set_roll_at(index, roll)
      roll_output[:children][index][:children][1][:textContent] = roll.to_s
    end

    def set_total(rolls)
      total = rolls.all?(Numeric) ? rolls.sum : VectorNumber.new(rolls)
      node = roll_output[:children].namedItem("roll-total")
      node[:textContent] = total.to_s
      node[:classList].toggle("just-rolled", true)
      JS.global[:setTimeout].apply(-> { node[:classList].toggle("just-rolled", false) }, 100)
    end
  end
end

module DistributionCalculator
  SELECTOR = Dicey::SumFrequencyCalculators::AutoSelector.new

  class << self
    def calculate(dice)
      results = SELECTOR.call(dice).call(dice)
      total_weight = results.values.sum
      results.transform_values { [_1, Rational(_1, total_weight)] }
    end
  end
end

module DistributionController
  class << self
    def update_distribution(dice)
      results = DistributionCalculator.calculate(dice)
      max_percentage = results.values.map(&:last).max
      data = results.map do |outcome, (weight, probability)|
        percentage = (probability * 100).to_f.round(2)
        [outcome.to_s, weight.to_s, probability, percentage, percentage / max_percentage]
      end
      results_table_body.replaceChildren(*build_table_rows(data))
    end

    private

    def results_table_body
      DOCUMENT.getElementById("results-table-body")
    end

    def build_table_rows(data)
      return [] if data.empty?

      data.map do |(outcome, weight, probability, percentage, ratio)|
        probability_string = "#{probability.numerator}​/​#{probability.denominator}"
        RAX.("tr") do
          [
            RAX.("td") { outcome },
            RAX.("td") { weight },
            RAX.("td") { "#{probability_string} (#{percentage}%)" },
            RAX.("td") do
              RAX.("div", class: "probability-bar-container") do
                RAX.("div", class: "probability-bar", "data-ratio": "#{ratio}%")
              end
            end,
          ]
        end
      end
    end
  end
end

# --- Set up event listeners

# Common dice
buttons = DOCUMENT.getElementById("dice-selection").querySelectorAll(".dice-button").to_a
buttons.each do |die_button|
  die_button.addEventListener("click") do |e|
    DiceSelection.add_dice(die_button[:dataset][:die])
  end
end

# Custom dice
custom_dice_input = DOCUMENT.getElementById("custom-dice-input")
custom_dice_form = DOCUMENT.getElementById("custom-dice-form")
custom_dice_form.addEventListener("submit") do |e|
  e.preventDefault
  next unless custom_dice_input[:validity][:valid] == JS::True

  value = custom_dice_input[:value]
  DiceSelection.add_dice(value)
end

# Clear dice button
clear_button = DOCUMENT.getElementById("clear-button")
clear_button.addEventListener("click") do |e|
  DiceSelection.clear_dice
end

# Reroll button
reroll_button = DOCUMENT.getElementById("reroll-button")
reroll_button.addEventListener("click") do |e|
  RollController.reroll
end

# --- Main loop of observing dice selection

dice_updater = ->(dice) {
  DistributionController.update_distribution(dice)
  RollController.replace_roll(dice)
}
DiceSelection.add_observer(dice_updater, :call)

# --- All done, hide loader

DOCUMENT.getElementById("loader").hidePopover()
print "Running Dicey v#{Dicey::VERSION} and VectorNumber v#{VectorNumber::VERSION}"

# --- Add dice from URL parameters

params = JS.global[:URLSearchParams].new(WINDOW[:location][:search])
DiceSelection.add_dice(*params.keys.to_a)
search_params_updater = ->(dice) {
  WINDOW[:history].replaceState(nil, nil, "?#{dice.join("&")}")
}
DiceSelection.add_observer(search_params_updater, :call)
