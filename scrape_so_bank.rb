# coding: utf-8

require 'axlsx'
require 'date'
require 'open-uri'
require 'logger'
 
def get_hist_data(asin)
  url = "http://us.so-bank.jp/detail/?code=#{asin}&month=12"
  doc = open(url).read
  hist_data = {}
  get_hist_graph_data(doc, 'graph3').each do |date_rank|
    date = date_rank[0]
    rank = date_rank[1]
    hist_data[date] = { rank: rank }
  end
  get_hist_graph_data(doc, 'graph1').each do |date_price_seller|
    date = date_price_seller[0]
    price = date_price_seller[1]
    seller = date_price_seller[2]
    hist_data[date][:price] = price
    hist_data[date][:seller] = seller
  end
  hist_data
end

def get_hist_graph_data(doc, graph)
  script = get_script_text(doc, graph)
  if script
    data_line = get_data_line(script)
    eval("[ #{conv_date(data_line)} ]")
  else
    []
  end
end

def get_data_line(script_text)
  lines = script_text.split(/\n/)
  lines.each_with_index do |line, i|
    return lines[i+1].chomp.strip if line =~ /^\s*data\.addRows\(\[/
  end
end

def get_script_text(doc, graph)
  scripts = doc.scan(/<script[^>]*>[^<]+<\/script>/m).select do |script|
    script =~ /function drawContinuousDateChart/
  end
  scripts.each do |script|
    return script if script =~ /#{graph}/
  end
  nil
end

def conv_date(data_line)
  data_line.gsub(/(\d{4}),(\d{1,2}),(\d{2})/) do
    mon = $2.to_i + 1
    "#{$1}, #{mon} ,#{$3.sub(/^0/,'')}"
  end.gsub(/new Date/, 'Date.new')
end

def write_to_excel(asin, hist_data, out_file)
  package = Axlsx::Package.new                             
  sheet = package.workbook.add_worksheet(name: asin)
  sheet.add_row(['日付', 'ランキング', '価格', 'セラー数']) 
  hist_data.each do |date, data|
    sheet.add_row([date, data[:rank], data[:price], data[:seller]]) 
  end
  package.serialize out_file
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
logger = MultiLogger.new("#{log_dir}/scrape_so_bank.log", 10)

in_str = open("#{__dir__}/asin.txt") { |f| f.read.chomp }
in_str.split(/\n/).each do |line|
  asin = line.chomp
  begin
    hist_data = get_hist_data(asin)
    out_file = "#{out_dir}/#{asin}.xlsx"
    write_to_excel(asin, hist_data, out_file)
    logger.info("#{asin} completed.")
  rescue => ex
    logger.error("#{asin} failed.")
    logger.error(ex.to_s)
    logger.error(ex.backtrace.join("\n"))
  end
end
