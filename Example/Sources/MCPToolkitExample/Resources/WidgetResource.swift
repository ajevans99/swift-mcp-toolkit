import MCPToolkit

struct WidgetResource: MCPResource {
  let uri = "ui://widget/myWidget.html"
  let name: String? = "My Widget"
  let description: String? = "A simple HTML widget"
  let mimeType: String? = "text/html"

  var content: Content {
    Group {
      "<!DOCTYPE html>"
      "<html><body>"
      "<h1>Hello from Widget!</h1>"
      "</body></html>"
    }
    .mimeType("text/html")
  }
}
