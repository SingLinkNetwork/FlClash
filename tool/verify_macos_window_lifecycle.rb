# frozen_string_literal: true

source = File.read(
  File.expand_path('../macos/Runner/MainFlutterWindow.swift', __dir__),
)

abort 'MainFlutterWindow must not override NSWindow.order during nib loading' if
  source.match?(/override\s+(?:public\s+)?func\s+order\s*\(/)

awake_from_nib = source.index('override func awakeFromNib()')
super_awake = source.index('super.awakeFromNib()', awake_from_nib)
hidden_at_launch = source.index('hiddenWindowAtLaunch()', awake_from_nib)

abort 'MainFlutterWindow awakeFromNib is missing' unless awake_from_nib
abort 'MainFlutterWindow must call super.awakeFromNib()' unless super_awake
abort 'hiddenWindowAtLaunch must be called after super.awakeFromNib()' unless
  hidden_at_launch && hidden_at_launch > super_awake
abort 'hiddenWindowAtLaunch must be called exactly once' unless
  source.scan('hiddenWindowAtLaunch()').length == 1

puts 'macOS MainFlutterWindow lifecycle verifier passed'
