import Foundation
import MCPToolkit

/// Example tool demonstrating structured output with stock market data.
///
/// This tool showcases how to use `MCPToolWithStructuredOutput` to return
/// both machine-readable structured data and human-friendly text content.
struct StockQuoteTool: MCPToolWithStructuredOutput {
  let name = "get_stock_quote"
  let description: String? = "Get current stock quote with detailed information"

  @Schemable
  struct Parameters: Codable, Sendable {
    /// Stock symbol (e.g., AAPL, GOOGL, MSFT)
    let symbol: String

    /// Include extended trading hours data
    let includeExtendedHours: Bool?
  }

  @Schemable
  struct StockOutput: Codable, Sendable {
    /// Stock symbol
    let symbol: String

    /// Current price in USD
    let price: Double

    /// Price change from previous close
    let change: Double

    /// Percentage change from previous close
    let changePercent: Double

    /// Trading volume
    let volume: Int

    /// Market capitalization in billions USD
    let marketCap: Double

    /// 52-week high price
    let high52Week: Double

    /// 52-week low price
    let low52Week: Double
  }

  typealias Output = StockOutput

  func produceOutput(with arguments: Parameters) async throws(ToolError) -> Output {
    // Simulate fetching stock data
    // In a real implementation, this would call a stock market API
    let mockData: [String: (price: Double, change: Double, volume: Int, marketCap: Double)] = [
      "AAPL": (178.50, 2.35, 52_847_293, 2_800.0),
      "GOOGL": (142.30, -1.20, 28_934_821, 1_750.0),
      "MSFT": (380.75, 5.60, 31_928_472, 2_830.0),
      "TSLA": (242.80, -8.45, 115_382_947, 771.0),
    ]

    guard let data = mockData[arguments.symbol.uppercased()] else {
      throw ToolError("Stock symbol '\(arguments.symbol)' not found")
    }

    let changePercent = (data.change / (data.price - data.change)) * 100

    return Output(
      symbol: arguments.symbol.uppercased(),
      price: data.price,
      change: data.change,
      changePercent: changePercent,
      volume: data.volume,
      marketCap: data.marketCap,
      high52Week: data.price * 1.15,
      low52Week: data.price * 0.75
    )
  }

  func content(for output: Output, arguments: Parameters) throws(ToolError) -> Content {
    let changeSymbol = output.change >= 0 ? "📈" : "📉"
    let changeSign = output.change >= 0 ? "+" : ""

    "Stock Quote: \(output.symbol)"
    ""
    "Current Price: $\(String(format: "%.2f", output.price))"
    "\(changeSymbol) Change: \(changeSign)$\(String(format: "%.2f", output.change)) (\(changeSign)\(String(format: "%.2f", output.changePercent))%)"
    ""
    "Trading Volume: \(formatNumber(output.volume))"
    "Market Cap: $\(String(format: "%.1f", output.marketCap))B"
    ""
    "52-Week Range: $\(String(format: "%.2f", output.low52Week)) - $\(String(format: "%.2f", output.high52Week))"

    if arguments.includeExtendedHours == true {
      ""
      "ℹ️ Extended hours data is currently unavailable"
    }
  }

  // Helper function to format large numbers with commas
  private func formatNumber(_ number: Int) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    return formatter.string(from: NSNumber(value: number)) ?? String(number)
  }
}
