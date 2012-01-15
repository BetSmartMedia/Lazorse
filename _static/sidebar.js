$(document).ready(function() {
    /* jQuery .offset appears to not work correctly in firefox */
    function yOffset(elem) {
        offset = 0
        do {
            offset += elem.offsetTop
        } while(elem = elem.offsetParent)
        return offset
    }
    
    var sections = $('div.section').get().map(function (node) {
        node.yTop = yOffset(node)
        var header = $(node).children('h1, h2').first()
        node.yBottom = yOffset(header.get(0)) + header.outerHeight()
        return node
    })

    function currentSection(section) {
        var w = $(window)
        var top = w.scrollTop()
        var bottom = w.scrollTop() + w.height()
        var half = top + ((bottom - top) * 0.66)
        var section = sections.filter(function (section) {
            return section.yBottom >= top && section.yTop < half
        })[0]

        if (!section || $(section).hasClass('currentsection')) return

        $(".currentsection").removeClass('currentsection')
        $(section).addClass('currentsection')
        $(".sphinxsidebar a[href='#" + section.id + "']")
            .parent().addClass('currentsection')
    }

    $(window).scroll(currentSection)
    $('.sphinxsidebar a.internal.reference').click(function() {
        var id = this.href.split('#').pop()
        currentSection(document.getElementById(id))
    })
    currentSection()
})
