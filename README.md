[![Build Status](https://travis-ci.org/skcc321/deploy_pin.svg?branch=master)](https://travis-ci.org/skcc321/deploy_pin)
[![Maintainability](https://api.codeclimate.com/v1/badges/c0a9ca97c1f9c0478ffc/maintainability)](https://codeclimate.com/github/skcc321/deploy_pin/maintainability)
[![Test Coverage](https://api.codeclimate.com/v1/badges/c0a9ca97c1f9c0478ffc/test_coverage)](https://codeclimate.com/github/skcc321/deploy_pin/test_coverage)

# DeployPin

![DeployPin](http://hereisfree.com/content1//pic/zip/2009109935062477801.jpg)

Sometimes we need to execute set of commands (tasks) after/before deployment.
Most likely you use migrations for such things, but that is not what is related to migration at all.
Also sometimes you need to execute some code before migration or later, after migration without blocking of main thread.

deploy_pins is exactly what you need.

## Usage
`rake deploy_pin:task`.

## Installation
Add this line to your application's Gemfile:

```ruby
gem 'deploy_pin'
```

And then execute:
```bash
$ bundle
```

Or install it yourself as:
```bash
$ gem install deploy_pin
```

## Contributing
Contribution directions go here.

## License
The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
