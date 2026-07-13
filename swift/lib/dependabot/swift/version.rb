# typed: strong
# frozen_string_literal: true

require "sorbet-runtime"

require "dependabot/utils"
require "dependabot/version"

module Dependabot
  module Swift
    class Version < Dependabot::Version
      extend T::Sig

      # Dependabot::Version::SEMVER_REGEX uses ^/$ line anchors; anchor to whole string to reject multiline input.
      SEMVER_ANCHORED = T.let(/\A#{SEMVER_REGEX.source}\z/x, Regexp)

      sig { override.params(version: VersionParameter).returns(T::Boolean) }
      def self.correct?(version)
        return false if version.nil?

        # Strict SemVer only: rejects dot-style prereleases ("1.0.0.alpha"), four-segment
        # versions ("0.0.0.0"), leading zeros ("01.2.3") and multiline input.
        version.to_s.delete_prefix("v").match?(SEMVER_ANCHORED)
      end

      sig { override.params(version: VersionParameter).void }
      def initialize(version)
        @version_string = T.let(version.to_s.dup.freeze, String)
        @prerelease_suffix = T.let(nil, T.nilable(String))

        # Drop the SemVer build metadata for comparison/equality; keep it only in to_s.
        core = T.must(version.to_s.delete_prefix("v").split("+").first)
        # Canonical SemVer form (build metadata stripped) used by to_semver/eql?/hash.
        @semver = T.let(core, String)

        if core.include?("-")
          base, suffix = core.split("-", 2)
          @prerelease_suffix = suffix
          super(T.must(base))
        else
          super(core)
        end
      end

      sig { override.returns(String) }
      def to_s
        @version_string
      end

      sig { override.returns(String) }
      def to_semver
        @semver
      end

      sig { override.returns(T::Boolean) }
      def prerelease?
        !@prerelease_suffix.nil?
      end

      sig { params(other: Object).returns(T::Boolean) }
      def eql?(other)
        return false unless other.is_a?(Version)

        to_semver == other.to_semver
      end

      sig { override.returns(Integer) }
      def hash
        to_semver.hash
      end

      sig { params(other: Object).returns(T.nilable(Integer)) }
      def <=>(other)
        return nil if other.nil?

        unless other.is_a?(Version)
          normalized = other.to_s.delete_prefix("v")
          return nil unless Gem::Version.correct?(normalized)

          # Non-SemVer operands (e.g. a RubyGems-normalized "2.54.0.pre.beta.1" requirement
          # boundary) fall back to Gem::Version ordering so comparison never raises. SemVer
          # section 11 pre-release precedence is only applied between two SemVer versions.
          return Gem::Version.new(to_semver) <=> Gem::Version.new(normalized)
        end

        result = super
        return result if result.nil? || !result.zero?

        compare_semver_prerelease(@prerelease_suffix, other.prerelease_suffix)
      rescue ArgumentError
        nil
      end

      protected

      sig { returns(T.nilable(String)) }
      attr_reader :prerelease_suffix

      private

      # SemVer section 11 pre-release precedence: 1.0.0-alpha < 1.0.0-alpha.1 < 1.0.0.
      sig { params(left: T.nilable(String), right: T.nilable(String)).returns(Integer) }
      def compare_semver_prerelease(left, right)
        return 0 if left.nil? && right.nil?
        return 1 if left.nil?
        return -1 if right.nil?

        left_ids = left.split(".")
        right_ids = right.split(".")

        # Compare identifiers pairwise over the common prefix.
        [left_ids.length, right_ids.length].min.times do |i|
          cmp = compare_semver_identifier(T.must(left_ids[i]), T.must(right_ids[i]))
          return cmp unless cmp.zero?
        end

        # All shared identifiers equal: more pre-release fields ranks higher (1.0.0-alpha < 1.0.0-alpha.1).
        left_ids.length <=> right_ids.length
      end

      sig { params(left: String, right: String).returns(Integer) }
      def compare_semver_identifier(left, right)
        left_numeric = left.match?(/\A\d+\z/)
        right_numeric = right.match?(/\A\d+\z/)

        if left_numeric && right_numeric
          left.to_i <=> right.to_i
        elsif left_numeric
          -1
        elsif right_numeric
          1
        else
          T.must(left <=> right)
        end
      end
    end
  end
end

Dependabot::Utils
  .register_version_class("swift", Dependabot::Swift::Version)
