[![Build Status](https://travis-ci.org/skcc321/dumpman.svg?branch=master)](https://travis-ci.org/skcc321/dumpman)
[![Maintainability](https://api.codeclimate.com/v1/badges/3f69b1bb862be2a7e6ce/maintainability)](https://codeclimate.com/github/skcc321/dumpman/maintainability)
[![Test Coverage](https://api.codeclimate.com/v1/badges/3f69b1bb862be2a7e6ce/test_coverage)](https://codeclimate.com/github/skcc321/dumpman/test_coverage)

# DeployPin

![alt text](https://png.pngtree.com/element_origin_min_pic/16/09/02/1557c923e3b4e16.jpg "DeployPin")

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
