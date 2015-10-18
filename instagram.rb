# Scrape all of a user's instagram photos
# Organize them into year and month folders
# Set correct exif time and comment with jhead
# Option to scrape only new photos since the last scrape

# HOWTO:
# - set `USERNAME`
# - if scraping all photos, reset `LAST_SCRAPED_ID` to nil
# - run script, look for saved photos in `#{ USERNAME }` directory
# - after script finishes, follow instruction to set `LAST_SCRAPED_ID`

require 'net/http'
require 'csv'
require 'json'

USERNAME = 'skwii'
LAST_SCRAPED_ID = '1097974222390660384_307146'

# Recursively crawl all new photos, sorted by created_at desc, for a user
def crawl(username, last_scraped_id, max_id = nil, items = [])
  # Construct url for the current page of photos
  url = "https://instagram.com/#{ username }/media/"
  url += "?&max_id=#{ max_id }" if max_id

  # Make network call and parse json
  uri = URI.parse(url)
  response = Net::HTTP.get_response(uri)
  json = JSON.parse(response.body)

  # Raise error if there is any
  raise url if json['status'] != 'ok'

  # Short circuit if we have already reached the last scraped photo
  last_scraped_id_index = json['items'].map { |item| item['id'] }.index(last_scraped_id)
  if last_scraped_id_index
    items.concat(json['items'][0...last_scraped_id_index])
    puts "crawled #{ items.size } items, reached last scraped photo, done"
    return items
  end

  # Append photos from this page to the recursive collection
  items = items.concat(json['items'])

  # Recursively crawl the next page; otherwise, we've crawled everything
  if json['more_available']
    puts "crawled #{ items.size } items, more available (max_id = #{ json['items'][-1]['id'] })"
    crawl(username, last_scraped_id, json['items'][-1]['id'], items)
  else
    puts "crawled #{ items.size } items, reached the end, done"
  end

  # Return all the photos crawled
  items
end

# Save photo with exif time and comment in year/month subfolder
def save(item)
  url = item['images']['standard_resolution']['url']
  created_at = Time.at(item['created_time'].to_i)
  folder_name = "#{ USERNAME }/#{ created_at.strftime("%Y/%m") }"
  file_path = "#{ folder_name }/#{ item['id'] }.jpg"

  # Organize photos into year and month folders
  `mkdir -p #{ folder_name }`

  # Download photo
  `curl -s -o #{ file_path } #{ url }`

  # Set exif time
  `./jhead-3.00 -mkexif -ts#{ created_at.strftime('%Y:%m:%d-%T') } #{ file_path }`

  # Set exif comment to include location and caption
  location = item['location']['name'] if item['location'] && item['location']['name']
  caption = item['caption']['text'] if item['caption'] && item['caption']['text']
  comment = [location, caption].compact.join(' | ')
                               .gsub(/\n/, ' ')
                               .gsub(/\s+/, ' ')
                               .gsub(/"/, "'")
  `./jhead-3.00 -cl "#{ comment }" #{ file_path }`

  puts "saved #{ item['id'] }"
end

items = crawl(USERNAME, LAST_SCRAPED_ID)
items.each do |item|
  save(item)
  sleep 0.5
end

# Print instruction to reset `LAST_SCRAPED_ID`
if !items.empty? && LAST_SCRAPED_ID != items[0]['id']
  puts
  puts 'TODO:'
  puts "set LAST_SCRAPED_ID = '#{ items[0]['id'] }'"
end
