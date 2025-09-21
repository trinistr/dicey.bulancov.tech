require "observer"

require "js"
require "js/require_remote"

JS::RequireRemote.instance.load("dicey.pack.rb")

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

    def add_die(value)
      value = value.to_s.strip
      return false if value.empty?

      chip = build_die_chip(value)
      selected_dice_list.appendChild(chip)
      changed
      notify_observers
      chip
    end

    def remove_die(node)
      node.remove
      changed
      notify_observers
      node
    end

    def dice
      selected_dice_list[:children].to_a.map { |chip| FOUNDRY.call(chip[:dataset][:die].to_s) }
    end

    private

    def selected_dice_list
      DOCUMENT.getElementById("selected-dice-list")
    end

    def build_die_chip(value)
      name = determine_die_name(value)
      chip =
        RAX.("div", class: "dice-chip", "data-die": name) do
          [
            name,
            RAX.("button", "aria-label": "Remove") { "×" },
          ]
        end
      add_remove_listener_to_chip(chip)
      chip
    end

    def add_remove_listener_to_chip(chip)
      chip.querySelector("button").addEventListener("click") { remove_die(chip) }
    end

    def determine_die_name(value)
      FOUNDRY.call(value).to_s
    end
  end
end

module RollController
  class << self
    def update_roll(dice)
      roll_output.replaceChildren and return if dice.empty?

      rolls = dice.map { [_1, _1.roll] }
      display_roll(rolls)
    end

    private

    def display_roll(rolls)
      results = rolls.map { |(die, roll)| build_die_roll(die, roll) }
      results.each_with_index do |node, index|
        node.addEventListener("click") do |e|
          rolls[index] = [rolls[index].first, rolls[index].first.roll]
          display_roll(rolls)
        end
      end
      results << build_roll_total(rolls.sum(&:last))
      roll_output.replaceChildren(*results)
    end

    def roll_output
      DOCUMENT.getElementById("roll-output")
    end

    def build_die_roll(die, roll)
      description = die.to_s

      RAX.("button", class: "die-roll-container") do
        [
          RAX.("div", class: "die-description", "data-die": description) { description },
          RAX.("div", class: "die-roll") { roll }
        ]
      end
    end

    def build_roll_total(total)
      RAX.("div", class: "roll-total") { total }
    end
  end
end

module DistributionCalculator
  CALCULATORS = [
    Dicey::SumFrequencyCalculators::KroneckerSubstitution.new,
    Dicey::SumFrequencyCalculators::MultinomialCoefficients.new,
    Dicey::SumFrequencyCalculators::BruteForce.new,
  ].freeze

  class << self
    def calculate(dice)
      results = CALCULATORS.find { |calculator| calculator.valid_for?(dice) }.call(dice)
      total = results.values.sum
      results.transform_values { [_1, Rational(_1, total)] }
    end
  end
end

module DistributionController
  class << self
    def update_distribution(dice)
      results = DistributionCalculator.calculate(dice)
      max = results.values.map(&:last).max
      data = results.map do |outcome, (weight, probability)|
        percentage = (probability * 100).to_f.round(2)
        [outcome.to_s, weight.to_s, probability, percentage, percentage / max]
      end
      results_table_body.replaceChildren(*build_table_rows(data))
    end

    private

    def results_table_body
      DOCUMENT.getElementById("results-table-body")
    end

    def build_table_rows(data)
      return [empty_table_row] if data.empty?

      data.map do |(outcome, weight, probability, percentage, ratio)|
        RAX.("tr") do
          [
            RAX.("td") { outcome },
            RAX.("td") { weight },
            RAX.("td") { "#{probability} (#{percentage}%)" },
            RAX.("td") do
              RAX.("div", class: "probability-bar-container") do
                RAX.("div", class: "probability-bar", "data-ratio": "#{ratio}%")
              end
            end,
          ]
        end
      end
    end

    def empty_table_row
      RAX.("tr") do
        RAX.("td", colSpan: "5") { "Here be probabilities" }
      end
    end
  end
end

# --- Set up event listeners

# Common dice
[4, 6, 8, 10, 12, 20].each do |die_value|
  die_button = DOCUMENT.getElementById("die-d#{die_value}")
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
  RollController.update_roll(DiceSelection.dice)
end

# --- Main loop (via observing dice selection)

updater = ->(*) {
  dice = DiceSelection.dice
  DistributionController.update_distribution(dice)
  RollController.update_roll(dice)
}
DiceSelection.add_observer(updater, :call)

# --- All done, hide loader

DOCUMENT.getElementById("loader").hidePopover()
