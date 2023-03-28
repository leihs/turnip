require 'turnip/node/scenario_definition'
require 'turnip/node/tag'
require 'turnip/node/example'

module Turnip
  module Node
    #
    # @note ScenarioOutline metadata generated by Gherkin
    #
    #     {
    #       type: :Scenario,
    #       tags: [], # Array of Tag
    #       location: { line: 10, column: 3 },
    #       keyword: "Scenario Outline",
    #       name: "Scenario Outline Description",
    #       steps: []
    #     }
    #
    class ScenarioOutline < ScenarioDefinition
      include HasTags

      def examples
        @examples ||= @raw.examples.map do |raw|
          Example.new(raw)
        end
      end

      #
      # Return array of Scenario
      #
      # @note
      #
      #    example:
      #
      #      Scenario Outline: Test
      #        Then I go to <where>
      #
      #        Examples:
      #          | where   |
      #          | bank    |
      #          | airport |
      #
      #      to
      #
      #      Scenario: Test
      #        Then I go to bank
      #
      #      Scenario: Test
      #        Then I go to airport
      #
      # @return  [Array]
      #
      def to_scenarios
        return [] if examples.nil?

        @scenarios ||= examples.map do |example|
          header = example.header

          example.rows.map do |row|
            scenario = convert_metadata_to_scenario(header, row)

            #
            # Replace <placeholder> using Example values
            #
            scenario.steps.each do |step|
              step.text = substitute(step.text, header, row)

              case
              when step.block&.is_a?(CukeModeler::DocString)
                step.block.content = substitute(step.block.content, header, row)
              when step.block&.is_a?(CukeModeler::Table)
                step.block.rows.map do |table_row|
                  table_row.cells.map do |cell|
                    cell.value = substitute(cell.value, header, row)
                  end
                end
              end
            end

            Scenario.new(scenario)
          end
        end.flatten.compact
      end

      private

      #
      # Convert ScenariOutline metadata for Scenario
      #
      # @example:
      #
      #     {
      #       "type": "ScenarioOutline",
      #       "tags": ['tag'],
      #       "location": {'loc'},
      #       "keyword": "Scenario Outline",
      #       "name": "...",
      #       "steps": [],
      #       "examples": []
      #     }
      #
      #     to
      #
      #     {
      #       "type": "Scenario",
      #       "tags": ['tag'],
      #       "location": {'loc'},
      #       "keyword": "Scenario",
      #       "name": "...",
      #       "steps": []
      #     }
      #
      # @note At this method, placeholder of step text is not replaced yet
      #
      # @todo :keyword is not considered a language (en only)
      # @return  [Hash]
      #
      def convert_metadata_to_scenario(header, row)
        # deep copy
        original = Marshal.load(Marshal.dump(raw))

        CukeModeler::Scenario.new.tap do |scenario|
          scenario.name = substitute(original.name, header, row)
          scenario.keyword = 'Scenario' # TODO: Do we need to worry about dialects other than English?
          scenario.steps = original.steps
          scenario.source_line = original.source_line
          scenario.source_column = original.source_column
          scenario.tags = original.tags
        end
      end

      #
      # Replace placeholder `<..>`
      #
      # @example:
      #
      #    text = 'There is a <monster> that has <hp> hitpoints.'
      #    header = ['monster', 'hp']
      #    row = ['slime', '10']
      #
      #    substitute(text, header, row)
      #    # => 'There is a slime that has 10 hitpoints.'
      #
      # @param  text    [String]
      # @param  header  [Array]
      # @param  row     [Array]
      # @return [String]
      #
      def substitute(text, header, row)
        text.gsub(/<([^>]*)>/) { |_| Hash[header.zip(row)][$1] }
      end
    end
  end
end
