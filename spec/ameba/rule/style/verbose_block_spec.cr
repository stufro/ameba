require "../../../spec_helper"

module Ameba::Rule::Style
  subject = VerboseBlock.new

  describe VerboseBlock do
    it "passes if there is no potential performance improvements" do
      source = Source.new %(
        (1..3).any?(&.odd?)
        (1..3).join('.', &.to_s)
        (1..3).map { |i| typeof(i) }
        (1..3).map { |i| i || 0 }
      )
      subject.catch(source).should be_valid
    end

    it "reports if there is a call with a collapsible block" do
      source = Source.new %(
        (1..3).any? { |i| i.odd? }
      )
      subject.catch(source).should_not be_valid
    end

    it "reports if there is a call with an argument + collapsible block" do
      source = Source.new %(
        (1..3).join('.') { |i| i.to_s }
      )
      subject.catch(source).should_not be_valid
    end

    it "reports if there is a call with a collapsible block (with chained call)" do
      source = Source.new %(
        (1..3).map { |i| i.to_s.split.reverse.join.strip }
      )
      subject.catch(source).should_not be_valid
    end

    context "properties" do
      it "#exclude_calls_with_block" do
        source = Source.new %(
          (1..3).in_groups_of(1) { |i| i.map(&.to_s) }
        )
        rule = VerboseBlock.new
        rule
          .tap(&.exclude_calls_with_block = true)
          .catch(source).should be_valid
        rule
          .tap(&.exclude_calls_with_block = false)
          .catch(source).should_not be_valid
      end

      it "#exclude_multiple_line_blocks" do
        source = Source.new %(
          (1..3).any? do |i|
            i.odd?
          end
        )
        rule = VerboseBlock.new
        rule
          .tap(&.exclude_multiple_line_blocks = true)
          .catch(source).should be_valid
        rule
          .tap(&.exclude_multiple_line_blocks = false)
          .catch(source).should_not be_valid
      end

      it "#exclude_operators" do
        source = Source.new %(
          (1..3).sum { |i| i * 2 }
        )
        rule = VerboseBlock.new
        rule
          .tap(&.exclude_operators = true)
          .catch(source).should be_valid
        rule
          .tap(&.exclude_operators = false)
          .catch(source).should_not be_valid
      end

      it "#exclude_setters" do
        source = Source.new %(
          Char::Reader.new("abc").tap { |reader| reader.pos = 0 }
        )
        rule = VerboseBlock.new
        rule
          .tap(&.exclude_setters = true)
          .catch(source).should be_valid
        rule
          .tap(&.exclude_setters = false)
          .catch(source).should_not be_valid
      end

      it "#max_line_length" do
        source = Source.new %(
          (1..3).tap &.tap &.tap &.tap &.tap &.tap &.tap do |i|
            i.to_s.reverse.strip.blank?
          end
        )
        rule = VerboseBlock.new
        rule
          .tap(&.max_line_length = 60)
          .catch(source).should be_valid
        rule
          .tap(&.max_line_length = nil)
          .catch(source).should_not be_valid
      end

      it "#max_length" do
        source = Source.new %(
          (1..3).tap { |i| i.to_s.split.reverse.join.strip.blank? }
        )
        rule = VerboseBlock.new
        rule
          .tap(&.max_length = 30)
          .catch(source).should be_valid
        rule
          .tap(&.max_length = nil)
          .catch(source).should_not be_valid
      end
    end

    context "macro" do
      it "reports in macro scope" do
        source = Source.new %(
          {{ (1..3).any? { |i| i.odd? } }}
        )
        subject.catch(source).should_not be_valid
      end
    end

    it "reports rule, pos and message" do
      source = Source.new path: "source.cr", code: %(
        (1..3).any? { |i| i.odd? }
      )
      subject.catch(source).should_not be_valid
      source.issues.size.should eq 1

      issue = source.issues.first
      issue.rule.should_not be_nil
      issue.location.to_s.should eq "source.cr:1:8"
      issue.end_location.to_s.should eq "source.cr:1:26"

      issue.message.should eq "Use short block notation instead: `any?(&.odd?)`"
    end
  end
end
