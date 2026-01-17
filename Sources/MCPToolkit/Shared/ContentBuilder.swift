/// A generic result builder for constructing content declaratively.
///
/// This builder provides a flexible way to construct arrays of content items
/// using Swift's result builder syntax, supporting conditionals, loops, and optionals.
@resultBuilder
public enum ContentBuilder<Item> {
  /// Builds a block of arrays, flattening them into a single array.
  public static func buildBlock(_ components: [Item]...) -> [Item] {
    components.flatMap { $0 }
  }

  /// Builds an expression from a single item.
  public static func buildExpression(_ item: Item) -> [Item] {
    [item]
  }

  /// Builds an expression from an array of items.
  public static func buildExpression(_ items: [Item]) -> [Item] {
    items
  }

  /// Builds an optional component.
  public static func buildOptional(_ component: [Item]?) -> [Item] {
    component ?? []
  }

  /// Builds a limited availability component.
  public static func buildLimitedAvailability(_ component: [Item]) -> [Item] {
    component
  }

  /// Builds the first branch of a conditional.
  public static func buildEither(first component: [Item]) -> [Item] {
    component
  }

  /// Builds the second branch of a conditional.
  public static func buildEither(second component: [Item]) -> [Item] {
    component
  }

  /// Builds the first branch of a conditional from a single item.
  public static func buildEither(first component: Item) -> [Item] {
    [component]
  }

  /// Builds the second branch of a conditional from a single item.
  public static func buildEither(second component: Item) -> [Item] {
    [component]
  }

  /// Builds an array from a loop or collection.
  public static func buildArray(_ components: [[Item]]) -> [Item] {
    components.flatMap { $0 }
  }
}
