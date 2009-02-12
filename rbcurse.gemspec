# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{rbcurse}
  s.version = "0.1.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Rahul Kumar"]
  s.date = %q{2009-02-11}
  s.description = %q{Ruby curses widgets for easy application development}
  s.email = %q{sentinel.2001@gmx.com}
  s.extra_rdoc_files = ["History.txt", "Manifest.txt", "README.txt"]
  s.files = ["History.txt", "Manifest.txt", "README.txt", "CHANGELOG", "Rakefile", "lib/rbcurse.rb", "test/test_rbcurse.rb", "lib/rbcurse/action.rb", "lib/rbcurse/applicationheader.rb", "lib/rbcurse/celleditor.rb", "lib/rbcurse/checkboxcellrenderer.rb", "lib/rbcurse/colormap.rb", "lib/rbcurse/comboboxcellrenderer.rb", "lib/rbcurse/defaultlistselectionmodel.rb", "lib/rbcurse/keylabelprinter.rb", "lib/rbcurse/listcellrenderer.rb", "lib/rbcurse/listkeys.rb", "lib/rbcurse/listscrollable.rb", "lib/rbcurse/listselectable.rb", "lib/rbcurse/mapper.rb", "lib/rbcurse/orderedhash.rb", "lib/rbcurse/rcombo.rb", "lib/rbcurse/rdialogs.rb", "lib/rbcurse/rform.rb", "lib/rbcurse/rinputdataevent.rb", "lib/rbcurse/rlistbox.rb", "lib/rbcurse/rmenu.rb", "lib/rbcurse/rmessagebox.rb", "lib/rbcurse/rpopupmenu.rb", "lib/rbcurse/rtabbedpane.rb", "lib/rbcurse/rtable.rb", "lib/rbcurse/rtextarea.rb", "lib/rbcurse/rtextview.rb", "lib/rbcurse/rwidget.rb", "lib/rbcurse/scrollable.rb", "lib/rbcurse/selectable.rb", "lib/rbcurse/table/tablecellrenderer.rb", "lib/rbcurse/table/tabledatecellrenderer.rb", "lib/ver/keyboard.rb", "lib/ver/keyboard2.rb", "lib/ver/ncurses.rb", "lib/ver/window.rb", "examples/qdfilechooser.rb", "examples/rfe.rb", "examples/rfe_renderer.rb", "examples/test1.rb", "examples/test2.rb", "examples/testcombo.rb", "examples/testkeypress.rb", "examples/testmenu.rb", "examples/testtable.rb", "examples/testtabp.rb", "examples/testtodo.rb", "examples/viewtodo.rb"]
  s.has_rdoc = false
  s.homepage = %q{http://rbcurse.rubyforge.org/}
  s.rdoc_options = ["--main", "README.txt"]
  s.require_paths = ["lib"]
  s.rubyforge_project = %q{rbcurse}
  s.rubygems_version = %q{1.3.1}
  s.summary = %q{Ruby curses widgets.}
  s.test_files = ["test/test_rbcurse.rb"]

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 2

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
      s.add_development_dependency(%q<hoe>, [">= 1.8.3"])
    else
      s.add_dependency(%q<hoe>, [">= 1.8.3"])
    end
  else
    s.add_dependency(%q<hoe>, [">= 1.8.3"])
  end
end
