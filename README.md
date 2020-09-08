A plugin to temporarily change ead export from archivesspace to match the type of eads expected by the finding aids publisher

## Scope
This plugin modifies the default behavior of the EAD export. The model and the serializer have been modified in line with the specifications given by ACM.

## Behavior
The way to override the default functionality is to find the method/model where the functionality has been coded and copy that to the plugin and change it to implement the new requirements.

For ex: backend/model/nyu_ead_model_extension.rb contains a method `addresslines` which has code that overrides the default functionality in ASpace.

## Plugin Organization
* plugin_info.txt: a file that contains the plugin version and the config invocation in ArchivesSpace to add the plugin. This is used in deployment to automatically add this plugin to the ASpace config file
* .travis.yml: yml file containing instructions for travis to generate builds based on the file's parameters
    * **Note**: To use travis, the user needs to register themselves with [travis](http://travis-ci.org) and give it permissions to the relevant repository.
* build.xml: xml file for the application build
* backend:
    * plugin_init.rb: file that contains calls to the files being used in the plugin
    * model:
        * nyu_ead_exporter.rb: file that serializes ASpace data into the EAD format. Extensive modifications have been made to the default EAD output.
        * nyu_ead_model_extension.rb: extension of the default EAD model. Contains code that overrides the address functionality.
