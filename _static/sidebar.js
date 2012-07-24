$(document).ready(function() {
  function yOffset(elem) {
    offset = 0
    do {
      offset += elem.offsetTop
    } while(elem = elem.offsetParent)
    return offset
  }
  
  var sectionNames = {}
  var sections = $('div.section').get().map(function (node) {
    node.yTop = yOffset(node)
    var header = $(node).children('h1, h2, h3').first()
    node.yBottom = yOffset(header.get(0)) + header.outerHeight()
    sectionNames[node.id] = node
    return node
  })

  function currentSection() {
    var w = $(window)
    var top = w.scrollTop()
    var bottom = w.scrollTop() + w.height()
    var half = top + ((bottom - top) * 0.66)
    var section = sections.filter(function (section) {
      return section.yBottom >= top && section.yTop < half
    })[0]

    if (!section || $(section).hasClass('currentsection')) return

    highlightSection(section)
  }

  function highlightSection(section) {
    if (!section) return
    $(".currentsection").removeClass('currentsection')
    $(section).addClass('currentsection')
    $(".sphinxsidebar a[href='#" + section.id + "']")
      .parent().addClass('currentsection')
  }

  $('.sphinxsidebar a.internal.reference').click(function() {
    var id = this.href.split('#').pop()
    highlightSection(document.getElementById(id))
  })

  $(window).scroll(currentSection)
  var hash;
  if (hash = document.location.hash) {
    highlightSection(sectionNames[hash.substring(1)])
  } else {
    currentSection()
  }
})
