describe Fastlane::Actions::AllureZephyrAction do
  describe '#run' do
    it 'prints a message' do
      expect(Fastlane::UI).to receive(:message).with("The allure_zephyr plugin is working!")

      Fastlane::Actions::AllureZephyrAction.run(nil)
    end
  end
end
