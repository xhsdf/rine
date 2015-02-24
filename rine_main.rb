#!/usr/bin/ruby

$:.push('.')
require 'line_management'


def main()
	Management.new("username", "password", "token").run()
end


main()