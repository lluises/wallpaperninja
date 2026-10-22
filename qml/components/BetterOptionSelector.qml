import QtQuick 2.12
import Lomiri.Components 1.3

OptionSelector {
  id: root

  // 0 = show every row. Set to e.g. 4 to cap the list and make it scroll.
  property int maxVisibleItems: 0

  // Replaces the SDK default, which never returns list.contentHeight
  // and therefore evaluates to 0 in the common case.
  containerHeight: itemHeight * (maxVisibleItems > 0
                                 ? Math.min(count, maxVisibleItems)
                                 : count)
}
