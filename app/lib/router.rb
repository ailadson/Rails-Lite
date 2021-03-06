class Route
  attr_reader :pattern, :http_method, :controller_class, :action_name

  def initialize(pattern, http_method, controller_class, action_name)
    @pattern = create_regex(pattern)
    @http_method = http_method
    @controller_class = eval(controller_class.to_s.camelcase + "Controller")
    @action_name = action_name
  end

  def create_regex(pattern)
    regex_pattern = pattern.split("/").drop(1).map do |step|
      if step[0] == ":"
        "(?<#{step[1...step.length]}>\\d+)"
      else
        step
      end
    end
    regex_pattern = "^/#{regex_pattern.join("/")}$"
    Regexp.new(regex_pattern)
  end

  # checks if pattern matches path and method matches request method
  def matches?(req)
    !(pattern =~ req.path).nil? && req.request_method.downcase == http_method.to_s
  end

  # use pattern to pull out route params (save for later?)
  # instantiate controller and call controller action
  def run(req, res)
    match_data = pattern.match(req.path)
    route_params = {}
    match_data.names.each{ |param| route_params[param] = match_data[param] }
    controller = @controller_class.new(req, res, route_params)
    controller.invoke_action(@action_name)
  end
end

class Router
  attr_reader :routes

  def initialize
    @routes = []
  end

  # simply adds a new route to the list of routes
  def add_route(pattern, method, controller_class, action_name)
    routes.push(Route.new(pattern, method, controller_class, action_name))
  end

  # evaluate the proc in the context of the instance
  # for syntactic sugar :)
  def draw(&proc)
    instance_eval(&proc)
  end

  # make each of these methods that
  # when called add route
  [:get, :post, :put, :delete].each do |http_method|
    define_method(http_method) do |pattern, controller, action_name|
      add_route(pattern, http_method, controller, action_name)
    end
  end

  # should return the route that matches this request
  def match(req)
    routes.each do |route|
      return route if route.matches?(req)
    end
    nil
  end

  # either throw 404 or call run on a matched route
  def run(req, res)
    route = match(req)

    if route
      route.run(req, res)
    else
      res.status = 404
    end
  end
end
