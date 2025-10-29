require "observer"

require "js"
require "js/require_remote"

JS::RequireRemote.instance.load("dicey.pack.rb")
JS::RequireRemote.instance.load("vector_number.pack.rb")

DOCUMENT = JS.global[:document]

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

    attr_reader :dice

    def clear_dice
      reset_dice_set
      selected_dice_list.replaceChildren
      notify_observers
    end

    def add_die(value)
      value = value.to_s.strip
      return false if value.empty?

      new_dice = Array(FOUNDRY.call(value))
      add_dice_to_set(new_dice)

      chips = new_dice.map { |die| build_die_chip(die) }
      selected_dice_list.append(*chips)
      notify_observers
      chips
    end

    def remove_die(node, die)
      remove_die_from_set(die)
      node.remove
      notify_observers
      node
    end

    private

    def reset_dice_set
      @dice_set = Set.new.compare_by_identity
      reset_dice_array
    end

    def add_dice_to_set(dice)
      @dice_set.merge(dice)
      reset_dice_array
    end

    def remove_die_from_set(die)
      @dice_set.delete(die)
      reset_dice_array
    end

    def reset_dice_array
      @dice = @dice_set.to_a
    end

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
      add_remove_listener_to_chip(chip, die)
      chip
    end

    def add_remove_listener_to_chip(chip, die)
      chip.querySelector("button").addEventListener("click") { remove_die(chip, die) }
    end

    def notify_observers(...)
      changed
      super
    end
  end
end

module RollController
  class << self
    def replace_roll
      roll_output.replaceChildren and return if no_dice_selected?

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

    def current_dice
      DiceSelection.dice
    end

    def no_dice_selected?
      !current_dice || current_dice.empty?
    end

    def roll_output
      DOCUMENT.getElementById("roll-output")
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
  SELECTOR = Dicey::DistributionCalculators::AutoSelector.new

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
    def update_distribution
      results = DistributionCalculator.calculate(current_dice)
      max_percentage = results.values.map(&:last).max
      data = results.map do |outcome, (weight, probability)|
        percentage = (probability * 100).to_f.round(2)
        [outcome.to_s, weight.to_s, probability, percentage, percentage / max_percentage]
      end
      results_table_body.replaceChildren(*build_table_rows(data))
    end

    private

    def current_dice
      DiceSelection.dice
    end

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
    DiceSelection.add_die(die_button[:dataset][:die])
  end
end

# Custom dice
custom_dice_input = DOCUMENT.getElementById("custom-dice-input")
custom_dice_form = DOCUMENT.getElementById("custom-dice-form")
custom_dice_form.addEventListener("submit") do |e|
  e.preventDefault
  next unless custom_dice_input[:validity][:valid] == JS::True

  value = custom_dice_input[:value]
  DiceSelection.add_die(value)
end

# Reroll button
reroll_button = DOCUMENT.getElementById("reroll-button")
reroll_button.addEventListener("click") do |e|
  RollController.reroll
end

# --- Main loop of observing dice selection

DiceSelection.clear_dice

updater = ->(*) {
  RollController.replace_roll
  DistributionController.update_distribution
}
DiceSelection.add_observer(updater, :call)

# --- All done, hide loader

DOCUMENT.getElementById("loader").hidePopover()
print "Running Dicey #{Dicey::VERSION} and VectorNumber #{VectorNumber::VERSION}"
