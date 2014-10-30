#!/usr/bin/env ruby

require 'capybara'
require 'clockwork'
require 'capybara/poltergeist'
require 'twilio-ruby'

include Capybara::DSL
include Clockwork

Capybara.default_driver = :poltergeist

#http://robots.thoughtbot.com/automatically-wait-for-ajax-with-capybara
module WaitForAjax
  def WaitForAjax.wait_for_ajax
    Timeout.timeout(Capybara.default_wait_time) do
      loop until WaitForAjax.finished_all_ajax_requests?
    end
  end

  def WaitForAjax.finished_all_ajax_requests?
    page.evaluate_script('jQuery.active').zero?
  end
end

account_sid = ""
auth_token = ""

@client = Twilio::REST::Client.new account_sid, auth_token

def scrape
  twilio_phone_number = ""
  url = "http://store.apple.com/us/buy-iphone/iphone6/5.5-inch-display-64gb-"
  urls = ["silver-t-mobile", "gold-t-mobile", "space-gray-t-mobile"]

  urls.each do |color|
    variant = "#{url}#{color}"

    visit variant
    click_button("Check availability")
    fill_in('ZIP Code', :with => '')
    click_button("Search Stores")

    WaitForAjax.wait_for_ajax

    all(".retail-availability-search-store-item").each do |location|
      aval = location.find(".store-availability").text
      store = location.find(".store-name").text

      if !(aval == "Unavailable for Pickup")
        @client.messages.create(
          :from => "+1#{twilio_phone_number}",
          :to => "",
          :body => "Available - #{color} - #{store} - #{variant}"
        )
      end
    end
  end

  puts "all done!"
end

handler do |job|
  scrape
end

every(10.minutes, 'check for phones!')
