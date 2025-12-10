module Jekyll
  module Statistics
    def wc(input)
      stripped_input = input.gsub(%r{</?[^>]*>}, '')
      stripped_input.scan(/\w+/).size
    end

    def time(input)
      wpm = 200.0
      words =  wc(input)
      duration = (words / wpm).ceil
      duration
    end
  end
end

Liquid::Template.register_filter(Jekyll::Statistics)
