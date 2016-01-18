# coding: utf-8

require 'axlsx'
require 'csv'
require 'selenium-webdriver'
require 'yaml'
require 'logger'
 
class Browser
  def initialize(config, logger)
    @app = config['browser'].to_sym
    @max_try = config['max_try']
    @wait_time_base = config['wait_time_base']
    @logger = logger
    new_driver()
  end

  #attr_reader :driver, :max_try, :interval

  def open(url)
    (1..@max_try).each do |i|
      begin
        @driver.navigate.to url
        return yield @driver
      rescue SiteUnkownError => ex
        @logger.warn "#{i.ordinalize} try for #{url} failed." unless i == 1
        raise ex if i == @max_try
        wait_time = @wait_time_base * (2 ** (i-1))
        sleep wait_time
      rescue => ex
        quit()
        new_driver()
        raise ex
      end
    end
  end

  def quit
    @driver.quit
  end

  def save_screenshot(path)
    @driver.save_screenshot(path)
  end

  def refresh
    @driver.refresh
  end

  private

  def new_driver
    @driver = Selenium::WebDriver.for @app
  end
end

class Integer
  def ordinalize
    suffix =
      if (fd=abs%10).between?(1,3) && !abs.between?(11,13)
        %w(_ st nd rd)[fd]
      else
        'th'
      end
    "#{self}" + suffix
  end
end

class HistItem
  attr_accessor :survey_date, :ranking, :new_sell_price, :used_sell_price, :coll_sell_price
  def initialize
    @new_sell_price = SellerAndPrice.new
    @used_sell_price = SellerAndPrice.new
    @coll_sell_price = SellerAndPrice.new
  end

  def to_array
    [
      @survey_date,
      @ranking,
      @new_sell_price.num_of_sellers,
      @new_sell_price.lowest_price,
      @used_sell_price.num_of_sellers,
      @used_sell_price.lowest_price,
      @coll_sell_price.num_of_sellers,
      @coll_sell_price.lowest_price
    ]
  end
end

class SellerAndPrice
  attr_accessor :num_of_sellers, :lowest_price
end

class Warn < StandardError
  def initialize(asin)
    @asin = asin
  end

  def to_s
    @asin
  end

  def ==(asin)
    @asin <=> asin
  end
end

class NotFoundWarn < Warn
  def to_msg
    "#{@asin} (not found)"
  end
end

class EmptyWarn < Warn
  def to_msg
    "#{@asin} (empty)"
  end
end

class SiteUnkownError < StandardError
  def initialize(org_ex)
    super 'Unkwon site error occuered.'
    @org_ex = org_ex
  end

  alias :org_to_s :to_s

  def to_s
    "#{org_to_s}\n#{@org_ex.to_s}"
  end

  def backtrace
    @org_ex.backtrace
  end
end

def get_hist_data(browser, asin)
  url = "http://us.mnrate.com/item/aid/#{asin}"
  data = nil
  not_found = false
  browser.open(url) do |driver|
    begin
      unless page_not_found?(driver)
        5.times.each do |i|
          sleep 1.5 * (i + 1)
          data = get_hist_graph_data(driver)
          break unless data.empty?
          puts "refresh!!!"
          driver.refresh
        end
      else
        not_found = true
      end
    rescue => ex
      raise SiteUnkownError.new(ex)
    end
  end
  raise NotFoundWarn.new(asin) if not_found
  raise EmptyWarn.new(asin) if data.empty?
  data
end

def page_not_found?(driver)
  main = driver.find_element(:tag_name, 'main')
  section_text = main.find_element(:tag_name, 'section').text.chomp.strip
  section_text == "指定された商品情報が存在しませんでした。" or
    section_text == "There was no information about the product you selected."
end

def get_hist_graph_data(driver)
  driver.find_element(:id, 'sheet_contents')
    .find_element('tag_name', 'tbody')
    .find_elements(:tag_name, 'tr')

  script = <<EOS
  var rows = document.querySelectorAll('#sheet_contents tbody tr');
  var items = [];
  for (var i = 0; i < rows.length; i++){
    var item = {};
    ['w_res', 'w_ran', 'w_tnew', 'w_tuse', 'w_new', 'w_tuse', 'w_tcol', 'w_col'].forEach(function(klass) {
      var value = rows[i].querySelector('.' + klass).querySelector('span').textContent;
      item[klass] = value;
    });
    items.push(item);
  }
  return items;
EOS

  rows = driver.execute_script script
  rows.map do |row|
    item = HistItem.new
    item.survey_date = row['w_res'].sub(/^＞/, '')
    item.ranking = row['w_ran']
    item.new_sell_price.num_of_sellers = row['w_tnew']
    item.new_sell_price.lowest_price = row['w_new']
    item.used_sell_price.num_of_sellers = row['w_tuse']
    item.used_sell_price.lowest_price = row['w_use']
    item.coll_sell_price.num_of_sellers = row['w_tcol']
    item.coll_sell_price.lowest_price = row['w_col']
    item
  end
end

def get_col_text(hist_row, _class)
  hist_row.find_element(:class, _class).find_element(:tag_name, 'span').text.chomp.strip
end

def write_to_csv(asin, hist_items, out_file)
  CSV.open(out_file, 'w') do |csv|
    header.each do |row|
      csv << row
    end
     
    hist_items.each do |item|
      csv << item.to_array
    end
  end
end

def write_to_excel(asin, hist_items, out_file)
  package = Axlsx::Package.new                             
  sheet = package.workbook.add_worksheet(name: asin)

  # header
  header.each do |row|
    sheet.add_row row
  end

  # body
  hist_items.each do |item|
    sheet.add_row(item.to_array)
  end

  package.serialize(out_file)
end

def header
  [
    [
      'survey_date',
      'ranking',
      'new',
      '',
      'uesed',
      '',
      'collectible',
      ''
    ],
    [
      '',
      '',
      'number_of_sellers',
      'the_lowest_price',
      'number_of_sellers',
      'the_lowest_price',
      'number_of_sellers',
      'the_lowest_price'
    ]
  ]
end

class MultiLogger
  def initialize(log_path, num)
    @file_logger = Logger.new(log_path, num)
    @stdout_logger = Logger.new(STDOUT)
  end

  def method_missing(name, *args)
    @file_logger.send name, *args
    @stdout_logger.send name, *args
  end
end

#
# Main
#
out_dir = "#{__dir__}/out"
log_dir = "#{__dir__}/log"
[out_dir, log_dir].each do |dir|
  Dir.mkdir dir unless Dir.exist? dir
end

logger = MultiLogger.new("#{log_dir}/scrape_mnrate.log", 10)
logger.info "============= scrape_mnrate started!! ============="

config = YAML.load_file("config.yml")

browser = Browser.new config, logger

in_str = open("#{__dir__}/asin.txt") { |f| f.read.chomp }
result = {
  success: [],
  warning: [],
  error: []
}

in_str.split(/\n/).each do |line|
  asin = line.chomp
  begin
    hist_data = get_hist_data(browser, asin)
    if config['format'] == 'excel'
      out_file = "#{out_dir}/#{asin}.xlsx"
      write_to_excel(asin, hist_data, out_file)
    else
      out_file = "#{out_dir}/#{asin}.csv"
      write_to_csv(asin, hist_data, out_file)
    end
    result[:success] << asin
    logger.info("#{asin} successfull.")
  rescue NotFoundWarn => ex
    result[:warning] << ex
    logger.warn("#{asin} not found.")
  rescue EmptyWarn => ex
    result[:warning] << ex
    logger.warn("#{asin} is empty.")
  rescue => ex
    logger.error("#{asin} failed.")
    logger.error(ex.to_s)
    logger.error(ex.backtrace.join("\n"))
    result[:error] << asin
    if ex.is_a? SiteUnkownError
      browser.save_screenshot "#{log_dir}/#{asin}.png"
    end
  end
end

recovered = []
(result[:error] + result[:warning].select {|w| w.is_a? EmptyWarn}.map {|w| w.to_s}).each do |asin|
  logger.info("Last try for #{asin}.")
  begin
    hist_data = get_hist_data(browser, asin)
    if config['format'] == 'excel'
      out_file = "#{out_dir}/#{asin}.xlsx"
      write_to_excel(asin, hist_data, out_file)
    else
      out_file = "#{out_dir}/#{asin}.csv"
      write_to_csv(asin, hist_data, out_file)
    end
    recovered << asin
    logger.info("#{asin} successfull.")
  rescue NotFoundWarn => ex
    logger.warn("#{asin} not found.")
  rescue EmptyWarn => ex
    logger.warn("#{asin} is empty.")
  rescue SiteUnkownError => ex
      logger.error("#{asin} failed.")
      logger.error(ex.to_s)
      logger.error(ex.backtrace.join("\n"))
  end
end

recovered.each do |asin|
  result[:success] << asin
  result[:warning].delete asin
  result[:error].delete asin
end

browser.quit

logger.info "============= scrape_mnrate finished!! ============"
logger.info result.map {|s, asins| "#{s}: #{asins.size}"}.join(", ")
unless result[:warning].empty?
  logger.info "warnings:\n" + result[:warning].map {|w| w.to_msg}.join("\n")
end
unless result[:error].empty?
  logger.info "errors\n" + result[:error].join("\n")
end

