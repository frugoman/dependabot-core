# typed: false
# frozen_string_literal: true

require "spec_helper"
require "dependabot/swift/requirement"
require "dependabot/swift/version"

RSpec.describe Dependabot::Swift::Requirement do
  describe "#satisfied_by?" do
    subject(:satisfied_by?) { requirement.satisfied_by?(Dependabot::Swift::Version.new(version)) }

    let(:requirement) { described_class.new(">= 2.54.0, < 3.0.0") }

    context "with a version inside the range" do
      let(:version) { "2.55.0" }

      it { is_expected.to be true }
    end

    context "with the lower boundary" do
      let(:version) { "2.54.0" }

      it { is_expected.to be true }
    end

    context "with a version below the lower boundary" do
      let(:version) { "2.53.0" }

      it { is_expected.to be false }
    end

    context "with a version at the upper boundary" do
      let(:version) { "3.0.0" }

      it { is_expected.to be false }
    end
  end
end
