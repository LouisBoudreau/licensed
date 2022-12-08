# frozen_string_literal: true
require "test_helper"
require "tempfile"

describe Licensed::DependencyRecord do
  it "acts like a hash" do
    record = Licensed::DependencyRecord.new(metadata: { "name" => "test" })
    assert_equal "test", record["name"]
    record["name"] = "changed"
    assert_equal "changed", record["name"]
  end

  describe "read" do
    before do
      @filename = Tempfile.new("license").path
    end

    it "loads dependency information from a file" do
      data = {
        "name" => "test",
        "licenses" => ["license1", "license2"],
        "notices" => ["notice", "author"]
      }
      File.write(@filename, data.to_yaml)

      content = Licensed::DependencyRecord.read(@filename)
      assert_equal "test", content["name"]
      assert_equal ["license1", "license2"], content.licenses.map(&:text)
      assert_equal ["notice", "author"], content.notices
    end

    it "raises an error on invalid YAML" do
      File.write(@filename, "name: [")
      assert_raises Licensed::DependencyRecord::Error do
        Licensed::DependencyRecord.read(@filename)
      end
    end
  end

  describe "save" do
    before do
      @filename = Tempfile.new("license").path
    end

    it "writes text and metadata" do
      record = Licensed::DependencyRecord.new(licenses: "license", notices: "notice", metadata: { "name" => "test" })
      record.save(@filename)
      assert_equal <<~CONTENT, File.read(@filename)
        ---
        name: test
        licenses:
        - license
        notices:
        - notice
      CONTENT
    end

    it "always contains licenses and notices properties" do
      record = Licensed::DependencyRecord.new(metadata: { "name" => "test" })
      record.save(@filename)
      assert_equal <<~CONTENT, File.read(@filename)
        ---
        name: test
        licenses: []
        notices: []
      CONTENT
    end
  end

  describe "content" do
    it "returns nil if license text hasn't been set" do
      record = Licensed::DependencyRecord.new
      assert_nil record.content
    end

    it "returns joined text of all licenses sorted by text content" do
      record = Licensed::DependencyRecord.new(licenses: ["license1", "license2"])
      assert_equal "license1license2", record.content
    end

    it "returns license texts sorted by text sources when available" do
      record = Licensed::DependencyRecord.new(licenses: [{ "sources" => ["2"], "text" => "license1" }, { "sources" => ["1"], "text" => "license2" }])
      assert_equal "license2license1", record.content
    end
  end

  describe "matches?" do
    it "returns false for a non-DependencyRecord argument" do
      record = Licensed::DependencyRecord.new
      refute record.matches? nil
      refute record.matches? ""
    end

    it "returns true if the normalized content is the same for strings" do
      record = Licensed::DependencyRecord.new(licenses: "- test content")
      other = Licensed::DependencyRecord.new(licenses: "* test content")

      assert record.matches?(other)
    end

    it "returns true if the normalized content is the same for text+source data" do
      record = Licensed::DependencyRecord.new(licenses: { "text" => "- test content" })
      other = Licensed::DependencyRecord.new(licenses: { "text" => "* test content" })

      assert record.matches?(other)
    end

    it "returns true for the same normalized content in different ordered text-only data" do
      record = Licensed::DependencyRecord.new(licenses: ["license 1", "license 2"])
      other = Licensed::DependencyRecord.new(licenses: ["license 2", "license 1"])

      assert record.matches?(other)
    end

    it "returns true for the same normalized content in different ordered text+source data" do
      record = Licensed::DependencyRecord.new(licenses: [
        { "text" => "license 1", "source" => "source 1" },
        { "text" => "license 2", "source" => "source 2" }
      ])
      other = Licensed::DependencyRecord.new(licenses: [
        { "text" => "license 2", "source" => "source 2" },
        { "text" => "license 1", "source" => "source 1" }
      ])

      assert record.matches?(other)
    end
  end
end
