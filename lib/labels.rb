# Everything about creating and using labels in configuration

# TODO: detect labels such as win, lin, mac
# TODO: add configuration functions to simplify config management.

module Setup

def Setup.is_label(name)
  /<.*>/.match name
end

def Setup.get_config_value(data, label)
  if data.is_a?(Hash) and
      data.keys.all?(&method(:is_label)) and
      data.key?(label)
    return data[label]
  else
    return data
  end
end

class Labels

end

end
