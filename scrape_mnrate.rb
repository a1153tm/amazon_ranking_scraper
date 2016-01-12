# coding: utf-8

require 'axlsx'
require 'csv'
require 'selenium-webdriver'
require 'logger'
 
class Browser
  def initialize(app, logger)
    @app = app
    @logger = logger
    @max_try = 7
    @wait_base_time = 20
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
        wait_time = @wait_base_time * (2 ** (i-1))
        sleep wait_time
      rescue NotFoundError => ex
        raise ex
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

class NotFoundError < StandardError
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
  browser.open(url) do |driver|
    begin
      unless page_not_found?(driver)
        data = get_hist_graph_data(driver)
      else
        raise NotFoundError, "ASIN #{asin} not found." 
      end
    rescue => ex
      raise SiteUnkownError.new(ex)
    end
  end
  data
end

def page_not_found?(driver)
  main = driver.find_element(:tag_name, 'main')
  section_text = main.find_element(:tag_name, 'section').text.chomp.strip
  section_text == "指定された商品情報が存在しませんでした。"
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
  return rows.map do |row|
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
  #hist_items
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

app = ARGV[0].nil? ? :chrome : :firefox
browser = Browser.new app, logger

in_str = open("#{__dir__}/asin.txt") { |f| f.read.chomp }
result = {
  success: 0,
  warning: 0,
  error: 0
}
in_str.split(/\n/).each do |line|
  asin = line.chomp
  begin
    hist_data = get_hist_data(browser, asin)
    if ARGV[1] == 'excel'
      out_file = "#{out_dir}/#{asin}.xlsx"
      write_to_excel(asin, hist_data, out_file)
    else
      out_file = "#{out_dir}/#{asin}.csv"
      write_to_csv(asin, hist_data, out_file)
    end
    result[:success] += 1
    logger.info("#{asin} successfull.")
  rescue NotFoundError => ex
    result[:warning] += 1
    logger.warn("#{asin} #{ex.message}")
  rescue => ex
    logger.error("#{asin} failed.")
    logger.error(ex.to_s)
    logger.error(ex.backtrace.join("\n"))
    result[:error] += 1
    if ex.is_a? SiteUnkownError
      browser.save_screenshot "#{log_dir}/#{asin}.png"
    end
  end
end

browser.quit

logger.info "============= scrape_mnrate finished!! ============"
logger.info result
