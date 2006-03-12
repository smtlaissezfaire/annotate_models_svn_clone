require "config/environment"

MODEL_DIR   = File.join(RAILS_ROOT, "app/models")
FIXTURE_DIR = File.join(RAILS_ROOT, "test/fixtures")

module AnnotateModels

  PREFIX = "Schema as of "

  # Use the column information in an ActiveRecord class
  # to create a comment block containing a line for
  # each column. The line contains the column name,
  # the type (and length), and any optional attributes
  def self.get_schema_info(klass, header)
    info = "# #{header}\n#\n"
    klass.columns.each do |col|
      attrs = []
      attrs << "default(#{col.default})" if col.default
      attrs << "not null" unless col.null

      col_type = col.type.to_s
      col_type << "(#{col.limit})" if col.limit

      info << sprintf("#  %-20.20s:%-13.13s %s\n", col.name, col_type, attrs.join(", "))
    end

    info << "#\n\n"
  end

  # Add a schema block to a file. If the file already contains
  # a schema info block (a comment starting
  # with "Schema as of ..."), remove it first.

  def self.annotate_one_file(file_name, info_block)
    if File.exist?(file_name)
      content = File.read(file_name)

      # Remove old schema info
      content.sub!(/^# #{PREFIX}.*?\n(#.*\n)*\n/, '')

      # Write it back
      File.open(file_name, "w") { |f| f.puts info_block + content }
    end
  end
  
  # Given the name of an ActiveRecord class, create a schema
  # info block (basically a comment containing information
  # on the columns and their types) and put it at the front
  # of the model and fixture source files.

  def self.annotate(klass, header)
    info = get_schema_info(klass, header)
    
    model_file_name = File.join(MODEL_DIR, klass.name.underscore + ".rb")
    annotate_one_file(model_file_name, info)

    fixture_file_name = File.join(FIXTURE_DIR, klass.table_name + ".yml")
    annotate_one_file(fixture_file_name, info)
  end

  # Return a list of the model files to annotate. If we have 
  # command line arguments, they're assumed to be either
  # the underscore or CamelCase versions of model names.
  # Otherwise we take all the model files in the 
  # app/models directory.
  def self.get_model_names
    models = ARGV.dup
    models.shift
    
    if models.empty?
      Dir.chdir(MODEL_DIR) do 
        models = Dir["*.rb"]
      end
    end
    models
  end

  # We're passed a name of things that might be 
  # ActiveRecord models. If we can find the class, and
  # if its a subclass of ActiveRecord::Base,
  # then pas it to the associated block

  def self.do_annotations
    header = PREFIX + Time.now.to_s
    version = ActiveRecord::Migrator.current_version
    if version > 0
      header << " (schema version #{version})"
    end
    
    self.get_model_names.each do |m|
      class_name = Inflector.camelize(m.sub(/\.rb$/, ''))
      klass = Object.const_get(class_name) rescue nil
      if klass && klass < ActiveRecord::Base
        puts "Annotating #{class_name}"
        self.annotate(klass, header)
      else
        puts "Skipping #{class_name}"
      end
    end
  end
end
