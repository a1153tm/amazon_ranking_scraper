# coding: utf-8

require './lib/scrape_mnrate'
 
#
# Main
#
base_name = File.basename(__FILE__, ".rb")
suffix = base_name.match(/_([^_]+)$/)[1]

out_dir = "#{__dir__}/out_#{suffix}"
log_dir = "#{__dir__}/log_#{suffix}"
[out_dir, log_dir].each do |dir|
  Dir.mkdir dir unless Dir.exist? dir
end

logger = MultiLogger.new("#{log_dir}/#{base_name}.log", 10)
logger.info "============= #{base_name} started!! ============="

config = YAML.load_file("config_#{suffix}.yml")

browser = Browser.new config, logger

in_str = open("#{__dir__}/asin_#{suffix}.txt") { |f| f.read.chomp }
result = {
  success: [],
  warning: [],
  error: []
}

base_url = config['base_url']

in_str.split(/\n/).each do |line|
  asin = line.chomp
  begin
    hist_data = get_hist_data(browser, base_url, asin)
    if config['format'] == 'excel'
      out_file = "#{out_dir}/#{asin}.xlsx"
      write_to_excel(asin, hist_data, out_file)
    elsif config['format'] == 'txt'
      out_file = "#{out_dir}/#{asin}.txt"
      write_to_csv(asin, hist_data, out_file, "\t")
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
    hist_data = get_hist_data(browser, base_url, asin)
    if config['format'] == 'excel'
      out_file = "#{out_dir}/#{asin}.xlsx"
      write_to_excel(asin, hist_data, out_file)
    elsif config['format'] == 'txt'
      out_file = "#{out_dir}/#{asin}.txt"
      write_to_csv(asin, hist_data, out_file, "\t")
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
  result[:warning].delete_if { |w| w.to_s == asin }
  result[:error].delete asin
end

browser.quit

concatinate_out_files result[:success], out_dir, config['format']

logger.info "============= #{base_name} finished!! ============"
logger.info result.map {|s, asins| "#{s}: #{asins.size}"}.join(", ")
unless result[:warning].empty?
  logger.info "warnings:\n" + result[:warning].map {|w| w.to_msg}.join("\n")
end
unless result[:error].empty?
  logger.info "errors\n" + result[:error].join("\n")
end

