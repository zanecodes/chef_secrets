require "spec_helper"

describe Veil::CredentialCollection::Base do
  let(:salt)    { "$2a$11$4xS0IHHxU5sOYNNZ5X53Qe" }
  let(:secret)  { "ultrasecure" }
  let(:hasher)  { Veil::Hasher.create(type: "BCrypt", secret: secret, salt: salt) }

  subject { described_class.new(hasher: hasher.to_h) }

  describe "#self.create" do
    it "returns a credential store from the hash" do
      expect(described_class.create.class).to eq(described_class)
    end
  end

  describe "#new" do
    context "with hasher options" do
      it "builds the hasher instance" do
        hasher_hash = subject.hasher.to_h
        new_instance = described_class.new(hasher: hasher_hash)
        expect(new_instance.hasher.to_h).to eq(hasher_hash)
      end
    end

    context "with credential options" do
      it "builds the credentials" do
        subject.add("foo", "bar", length: 22)
        creds_hash = subject["foo"]["bar"].to_hash
        new_instance = described_class.new(credentials: { foo: { bar: creds_hash } })

        expected = subject["foo"]["bar"].value
        expect(new_instance["foo"]["bar"].value).to eq(expected)
      end
    end

    context "with version options" do
      it "defaults to version 1" do
        expect(subject.version).to eq(1)
      end

      it "sets the version" do
        new_instance = described_class.new(version: 12)
        expect(new_instance.version).to eq(12)
      end
    end
  end

  describe "#get" do
    before do
      subject.add("testkey0", value: "testvalue0")
      subject.add("testgroup", "testkey1", value: "testvalue1")
    end

    it "returns the value of a given credential" do
      expect(subject.get("testkey0")).to eq("testvalue0")
    end

    it "returns the value of a given credential in a group" do
      expect(subject.get("testgroup", "testkey1")).to eq("testvalue1")
    end

    it "raises an error if the credential isn't found" do
      expect { subject.get("dne") }.to raise_error(Veil::CredentialNotFound)
    end

    it "raises an error if the group isn't found" do
      expect { subject.get("dne", "tesetkey") }.to raise_error(Veil::GroupNotFound)
    end

    it "raises an error if the credential isn't found in the group" do
      expect { subject.get("testgroup", "dne") }.to raise_error(Veil::CredentialNotFound)
    end

    it "raises an error if the wrong number of arguments are given" do
      expect { subject.get("testgroup", "tesetkey", "whoops") }.to raise_error(ArgumentError)
    end
  end

  describe "#exist?" do
    it "returns false if the key does not exist" do
      expect(subject.exist?("Invalid Key")).to eq(false)
    end

    it "returns true if the key does exist" do
      subject.add("testkey0", value: "testvalue0")
      expect(subject.exist?("testkey0")).to eq(true)
    end
  end

  describe "#add_from_file" do
    context "when the file can be read" do
      # using this as our input file lets us do less mocking of
      # file sanity checks.
      let (:input_file) { "/" }
      let (:secret_content) { "a secret!" }

      before do
        allow(File).to receive(:read).with(input_file).and_return secret_content
      end

      context "with a name" do
        it "adds the contents of the file as a credential" do
          subject.add_from_file(input_file, "supersecret")
          cred = subject["supersecret"]
          expect(cred).to be_instance_of(Veil::Credential)
          expect(cred.value).to eq secret_content
          expect(cred.frozen).to be true
        end
      end

      context "with a group and name" do
        it "adds the contents of the file as a credential" do
          subject.add_from_file(input_file, "super", "secret")
          cred = subject["super"]["secret"]
          expect(cred).to be_instance_of(Veil::Credential)
          expect(cred.value).to eq secret_content
          expect(cred.frozen).to be true
        end
      end
    end

    context "when the file can not be read" do
      let (:input_file) { "/invalid" }

      it "fails with a FileNotReadable error" do
        expect { subject.add_from_file(input_file, "supersecret") }.to raise_error(Veil::FileNotReadable)
      end
    end
  end

  describe "#add" do
    it "creates a new credential" do
      subject.add("cowabunga")
      expect(subject["cowabunga"]).to be_instance_of(Veil::Credential)
    end

    context "with a name" do
      it "creates a new credential the right name" do
        subject.add("cowabunga")
        expect(subject["cowabunga"]).to be_instance_of(Veil::Credential)
        expect(subject["cowabunga"].name).to eq("cowabunga")
      end
    end

    context "with a group and name" do
      it "creates a new credential the right group and name" do
        subject.add("my_db", "password")
        expect(subject["my_db"]["password"]).to be_instance_of(Veil::Credential)
        expect(subject["my_db"]["password"].name).to eq("password")
      end
    end

    context "with a name and length" do
      it "creates a new credential the right name and length" do
        subject.add("conspiracy", length: 23)
        expect(subject["conspiracy"]).to be_instance_of(Veil::Credential)
        expect(subject["conspiracy"].length).to eq(23)
        expect(subject["conspiracy"].value.length).to eq(23)
      end
    end

    context "with a group, name, and length" do
      it "creates a new credential the right group and name" do
        subject.add("my_db", "password", length: 15)
        expect(subject["my_db"]["password"]).to be_instance_of(Veil::Credential)
        expect(subject["my_db"]["password"].name).to eq("password")
        expect(subject["my_db"]["password"].length).to eq(15)
        expect(subject["my_db"]["password"].value.length).to eq(15)
      end
    end

    context "with a group, name, default" do
      it "creates a new credential the right group and name" do
        subject.add("my_db", "password", value: "super_unison")
        expect(subject["my_db"]["password"]).to be_instance_of(Veil::Credential)
        expect(subject["my_db"]["password"].name).to eq("password")
        expect(subject["my_db"]["password"].value).to eq("super_unison")
      end
    end

    context "with a name and default" do
      it "creates a new credential the right group and name" do
        subject.add("luau", value: "new_math")
        expect(subject["luau"]).to be_instance_of(Veil::Credential)
        expect(subject["luau"].name).to eq("luau")
        expect(subject["luau"].value).to eq("new_math")
      end
    end

    context "when the credential already exists" do
      it "does not overwrite it" do
        subject.add("my_db", "password", length: 15)
        val = subject["my_db"]["password"].value
        subject.add("my_db", "password", value: "new-password")
        expect(subject["my_db"]["password"].value).to eq(val)
      end

      it "returns the existing credential" do
        subject.add("my_db", "password", length: 15)
        my_db = subject["my_db"]["password"]
        expect(subject.add("my_db", "password")).to eq(my_db)
      end

      context "when force: true is given as param" do
        it "does overwrite it" do
          subject.add("my_db", "password", length: 15)
          subject.add("my_db", "password", value: 'new-password', force: true)
          expect(subject["my_db"]["password"].value).to eq("new-password")
        end

        it "returns the new credential" do
          subject.add("my_db", "password", length: 15)
          expect(subject.add("my_db", "password", value: "new-password", force: true).value).to eq('new-password')
        end
      end

      context "when force: true is given as param and :frozen is not" do
        it "sets frozen to true" do
          subject.add("my_db", "password", value: 'new-password', force: true)
          expect(subject["my_db"]["password"].frozen).to eq(true)
        end
      end

      context "when force: true is given as param and :frozen is false" do
        it "sets frozen to false" do
          subject.add("my_db", "password", value: 'new-password', force: true, frozen: false)
          expect(subject["my_db"]["password"].frozen).to eq(false)
        end
      end

      context "when force: false is given as param and :frozen is true" do
        it "sets frozen to true" do
          subject.add("my_db", "password", value: 'new-password', force: true, frozen: true)
          expect(subject["my_db"]["password"].frozen).to eq(true)
        end

      end

      context "when force: false is given as param and :frozen is false" do
        it "sets frozen to false" do
          subject.add("my_db", "password", value: 'new-password', force: true, frozen: false)
          expect(subject["my_db"]["password"].frozen).to eq(false)
        end
      end
    end
  end

  describe "#remove" do
    context "with a cred" do
      context "with a match" do
        it "returns the value and removes the credential" do
          subject.add("funk")
          value = subject["funk"]
          expect(subject.remove("funk")).to eq(value)
          expect(subject["funk"]).to be_nil
        end

        context "when there is not a match" do
          it "returns nil" do
            expect(subject.remove("not_a_cred")).to be_nil
          end
        end
      end
    end

    context "with a group and cred" do
      context "with a match" do
        it "returns the value and removes the credential" do
          subject.add("grandfunk", "railroad")
          value = subject["grandfunk"]["railroad"]
          expect(subject.remove("grandfunk", "railroad")).to eq(value)
          expect(subject["grandfunk"]["railroad"]).to be_nil
        end

        context "when there is not a match" do
          it "returns nil" do
            expect(subject.remove("nested", "thing")).to be_nil
          end
        end
      end
    end
  end

  describe "#rotate_hasher" do
    it "creates a new hasher" do
      hasher = subject.hasher
      subject.rotate_hasher
      expect(subject.hasher).to_not eq(hasher)
    end

    it "rotates all credentials" do
      subject.add("foo")
      foo_val = subject["foo"].value
      subject.add("bar", "baz", length: 25)
      baz_val = subject["bar"]["baz"].value

      subject.rotate_hasher

      expect(subject["foo"].value).to_not eq(foo_val)
      expect(subject["foo"].version).to eq(1)
      expect(subject["bar"]["baz"].value).to_not eq(baz_val)
      expect(subject["bar"]["baz"].version).to eq(1)
    end

    context "with frozen credentials" do
      it "rotates all credentials that are not frozen" do
        subject.add("foo")
        foo_val = subject["foo"].value
        subject.add("bar", "baz", length: 25)
        baz_val = subject["bar"]["baz"].value
        subject.add("qux", "quux", frozen: true)
        baz_val = subject["qux"]["quux"].value

        subject.rotate_hasher

        expect(subject["foo"].value).to_not eq(foo_val)
        expect(subject["foo"].version).to eq(1)
        expect(subject["bar"]["baz"].value).to_not eq(baz_val)
        expect(subject["bar"]["baz"].version).to eq(1)
        expect(subject["qux"]["quux"].value).to eq(baz_val)
        expect(subject["qux"]["quux"].version).to eq(0)
      end
    end
  end

  describe "#rotate_credentials" do
    it "doesn't create a new hasher" do
      hasher = subject.hasher
      subject.rotate_credentials
      expect(subject.hasher).to eq(hasher)
    end

    it "rotates all credentials" do
      subject.add("foo")
      foo_val = subject["foo"].value
      subject.add("bar", "baz", length: 25)
      baz_val = subject["bar"]["baz"].value

      subject.rotate_credentials

      expect(subject["foo"].value).to_not eq(foo_val)
      expect(subject["foo"].version).to eq(1)
      expect(subject["bar"]["baz"].value).to_not eq(baz_val)
      expect(subject["bar"]["baz"].version).to eq(1)
    end

    context "with frozen credentials" do
      it "rotates all credentials that are not frozen" do
        subject.add("foo")
        foo_val = subject["foo"].value
        subject.add("bar", "baz", length: 25)
        baz_val = subject["bar"]["baz"].value
        subject.add("qux", "quux", frozen: true)
        baz_val = subject["qux"]["quux"].value

        subject.rotate_credentials

        expect(subject["foo"].value).to_not eq(foo_val)
        expect(subject["foo"].version).to eq(1)
        expect(subject["bar"]["baz"].value).to_not eq(baz_val)
        expect(subject["bar"]["baz"].version).to eq(1)
        expect(subject["qux"]["quux"].value).to eq(baz_val)
        expect(subject["qux"]["quux"].version).to eq(0)
      end
    end
  end

  describe "#rotate" do
    context "when the credential exists" do
      it "rotates the credential" do
        subject.add("life_choices")
        old_val = subject["life_choices"].value
        old_version = subject["life_choices"].version

        subject.rotate("life_choices")
        expect(subject["life_choices"].value).to_not eq(old_val)
        expect(subject["life_choices"].version).to eq(old_version + 1)
      end
    end

    context "when the credential does not exist" do
      it "returns nil" do
        expect(subject.rotate("not_a_cred")).to be_nil
      end
    end

    context "when passed a set name only" do
      it "rotates each credential" do
        subject.add("desert", "black_eagle")
        eagle_val = subject["desert"]["black_eagle"].value

        subject.add("desert", "mercury_six")
        mercury_val = subject["desert"]["mercury_six"].value

        subject.rotate("desert")

        expect(subject["desert"]["black_eagle"].value).to_not eq(eagle_val)
        expect(subject["desert"]["black_eagle"].version).to eq(1)
        expect(subject["desert"]["mercury_six"].value).to_not eq(mercury_val)
        expect(subject["desert"]["mercury_six"].version).to eq(1)
      end
    end

    context "with a frozen credential" do
      it "does not rotate the credential" do
        subject.add("mannequin", "republic", frozen: true)
        old_val = subject["mannequin"]["republic"].value

        subject.rotate("mannequin", "republic")

        expect(subject["mannequin"]["republic"].value).to eq(old_val)
        expect(subject["mannequin"]["republic"].version).to eq(0)
      end
    end
  end

  describe "#to_hash" do
    it "returns a valid hash" do
      subject.add("foo")
      subject.add("bar", "baz", length: 31)
      subject.add("saint", "matthew", frozen: true)

      new_instance = described_class.new(subject.to_hash)
      expect(new_instance["foo"].version).to eq(subject["foo"].version)
      expect(new_instance["foo"].value).to eq(subject["foo"].value)
      expect(new_instance["bar"]["baz"].version).to eq(subject["bar"]["baz"].version)
      expect(new_instance["bar"]["baz"].value).to eq(subject["bar"]["baz"].value)
      expect(new_instance["bar"]["baz"].length).to eq(subject["bar"]["baz"].length)
      expect(new_instance["saint"]["matthew"].version).to eq(subject["saint"]["matthew"].version)
      expect(new_instance["saint"]["matthew"].value).to eq(subject["saint"]["matthew"].value)
      expect(new_instance["saint"]["matthew"].frozen).to eq(subject["saint"]["matthew"].frozen)
    end
  end
end
