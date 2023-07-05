# taxalogue
*taxalogue* collects DNA sequences from several online sources ([BOLD](https://www.boldsystems.org/), [GenBank](https://www.ncbi.nlm.nih.gov/genbank/) & [GBOL](https://bolgermany.de/gbol1/ergebnisse/results)) and combines them to a reference database. The reference database is useable in the taxonomic assignment step of metabarcoding analyses. Taxonomic incongruencies between the different data sources can be harmonized with respect to available taxonomies. Various filtering options are available regarding sequence quality or metadata information.

***
## Table of contents
- [Prerequisites](#prerequisites)
- [Getting Started](#getting-started)
- [Additional filtering](#additional-filtering)
- [Basics](#basics)
- [More examples](#more-examples)

***
## Prerequisites
You need to have **ruby** installed. *taxalogue* is tested for ruby versions **2.6.6 - 3.2.2**. **If you use Ubuntu 22+ you need to have at least ruby version 3.1.0**. For detailed instructions go to https://www.ruby-lang.org/en/documentation/installation/ 

Additionally quite a bit of disk space is needed. The concrete size depends on the used taxon, but 40 Gigabytes of free disk space should be considered as a minimum requirement.

At last, *taxalogue* needs time. Especially the sequence download of species-rich taxa will take a while (e.g.: Arthropoda download takes more than a day). This is mainly because of download speed throttling by the source databases, but also because of occasional waiting times to not overload the providers.

***
## Getting started

1. Get the latest [release](https://github.com/nwnoll/taxalogue/releases)

        wget https://github.com/nwnoll/taxalogue/archive/refs/tags/v0.9.3.2.tar.gz

2. Unzip the file to a location of your choice

        tar xzf v0.9.3.2.tar.gz

3. Change to the directory where you unzipped the source code
        
        cd taxalogue-0.9.3.2

4. Install all the dependencies
	
        bundle lock --update        
        bundle install

        # If you do get an error message like: Could not find 'bundler' (2.4.10) required by your Gemfile.lock. (Gem::GemNotFoundException)
        
        # try the following (remove the '#'):
        # gem install bundler:2.4.10
        # bundle update --bundler
        # bundle lock --update
        # bundle install


5. Download records from up to three different source databases
	
	## Since BOLD now offers to download a snapshot of the current database, it is recommended to use it
	## The datapackages are listed at https://boldsystems.org/index.php/datapackages
	## Choose the most current snapshot and download "Data package (tar.gz compressed)"
	## For this step you need to be logged in, and therefore an account is needed.
	## If you don't want to register at boldsystems you could use, for all source databases and Arthropoda, this command: bundle exec ruby taxalogue.rb --taxon Arthropoda download --all 
	## But be warned this takes considerably longer than downloading the datapackage
	## After you have downloaded the datapackage, extract the .tsv file
	
	## If you want to create a database for e.g., Artrhopoda from GBOL, GenBank and you already downloaded the aforementioned 
	## BOLD datapackage, you can use the command below to download data from GenBank and GBOL
	bundle exec ruby taxalogue.rb --taxon Arthropoda download --gbol --genbank

If this is the first start of *taxalogue*, it starts by downloading taxonomies from NCBI and GBIF. After download, the taxonomies will be imported into a SQL database. The whole process might take a little less than 2 hours. If the setup for the taxonomies is complete, the download of the actual sequences begins. As mentioned earlier the duration of the download depends on the chosen taxon.


6. Check for download failures. Some downloads might fail due to download restrictions or connection losses. Check and automatically download the failed download with the following command examples. Change the directory pathes according to your own files.

        ## if you did not download the BOLD datapackage: bundle exec ruby taxalogue.rb --taxon Arthropoda download --bold_dir downloads/BOLD/Arthropoda-20220203T2218
        bundle exec ruby taxalogue.rb --taxon Arthropoda download --genbank_dir downloads/NCBIGENBANK/release256
        bundle exec ruby taxalogue.rb --taxon Arthropoda download --gbol_dir downloads/GBOL/GBOL_Dataset_Release-20210128


7. Classify the records. Change the directory pathes according to your own BOLD release location (.tsv).
        
        ## if you did not download the BOLD datapackage: bundle exec ruby taxalogue.rb --taxon Arthropoda classify --all
        bundle exec ruby taxalogue.rb --taxon Arthropoda classify --genbank --gbol --bold_release /path/to/bold_release.tsv
	       
 
8. Have a look at the results:

        ├── results/
        │   ├── Arthropoda-20210317T1604/
        │   │   ├── merged_output.tsv
        │   │   ├── merged_output.fas
        │   │   ├── merged_comparison.tsv
        │   │   ├── ncbi_genbank_download_info.txt
        │   │   ├── gbol_download_info.txt
        │   │   ├── bold_download_info.txt
        │   │   ├── taxalogue.txt

9. Done!

If this is the first start of *taxalogue*, it has to download and setup taxonomies. These are needed to correctly assign taxonomic lineage information in case of missing or erroneous data. Since these are several Gigabyte of data, this might take while. The download time for the actual sequence data from BOLD, GenBank and GBOL depends on the taxon, but will also take quite some time. After the data are downloaded, the taxonomic lookup, mapping and formatting starts and the output files get created. 

*taxalogue* without any options will by default create a reference database for the taxon Arthropoda. The default marker is co1 and also the only possible marker choice at the moment. Additional marker are planned for coming updates. The default taxonomy is from NCBI.

The output files are stored in the results folder, depending on your taxon choice and time there will be a folder called something like `Arthropoda-20210317T1604`. The first part is the used taxon and the second part shows date and time of the pogram start.

The `contaminants` folder contains sequences of frequent unwanted HTS generated by-products. These files can be used as separate reference databases to exclude these most probably unwanted reads from further analysis. Wolbachia is an endoparasite of many insects and could lead to misclassification if not excluded.

The main output files are `merged_output.fas` and `merged_output.tsv` if dereplication is not activated;`Arthropoda_derep_all_output.tsv` and `Arthropoda_derep_all_output.fas` otherwise. These will represent the reference databases. The tsv has some additional metadata information, e.g. the location where the specimen has been found. Since the different source databases contain records that have misspelings and or are considered as synonyms, there might be changes to the taxonomic information compared to the original. These are shown in `merged_comparison.tsv` or `Arthropoda_derep_all_comparison.tsv`. Go to the [taxonomy section](#taxonomy) for more information.

***
## Additional filtering
**Requires [vsearch](https://github.com/torognes/vsearch) to remove possible contaminants**

```console
## replace spaces with underscores, vsearch does not allow spaces
ruby scripts/underscore_fasta.rb results/Arthropoda-20210317T1604/Arthropoda_derep_all_output.fas > Arthropoda_derep_all_output_uc.fas

## remove sequences with stop codons and correct reverse complements, --genetic code 5 for invertebrates
ruby scripts/stop_codon_filter_and_rc_correcton.rb --input Arthropoda_derep_all_output_uc.fas --output Arthropoda_derep_all_output_uc_STPf.fas --genetic_code 5 --filter_info STPf.tsv

## remove gaps from sequences
ruby scripts/degap_fasta.rb Arthropoda_derep_all_output_uc_STPf.fas > Arthropoda_derep_all_output_uc_STPf_dg.fas

## remove possible contaminants
cat results/Arthropoda-20210317T1604/Homo_sapiens_output.fas results/Arthropoda-20210317T1604/Wolbachia_output.fas > contaminants.fas
vsearch --usearch_global Arthropoda_derep_all_output_uc_STPf_dg.fas --db contaminants.fas --maxaccepts 1 --maxrejects 0 --id 0.9 --dbmask none --qmask none --threads 32 --blast6out contaminants_search.b6 --matched matched_contaminants.fas --notmatched Arthropoda_derep_all_output_uc_STPf_dg_CONTf.fas

## remove sequences with more than 3 Ns
ruby scripts/filter_Ns.rb Arthropoda_derep_all_output_uc_STPf_dg_CONTf.fas Nf3_discarded.fas 3 > Arthropoda_derep_all_output_uc_STPf_dg_CONTf_Nf3.fas

## remove sequences that have less than 400 bp and more than 1569 bp
ruby scripts/length_filter.rb Arthropoda_derep_all_output_uc_STPf_dg_CONTf_Nf3.fas 400 1569 STPf_dg_CONTf_Nf3_Lf400_1569.tsv > Arthropoda_derep_all_output_uc_STPf_dg_CONTf_Nf3_Lf400_1569.fas

## some sequences had missing information, e.g. order info was missing => sequence taxon info was removed until class level
ruby scripts/remove_lower_than_missing_taxon_info.rb Arthropoda_derep_all_output_uc_STPf_dg_CONTf_Nf3_Lf400_1569.fas > Arthropoda_derep_all_output_uc_STPf_dg_CONTf_Nf3_Lf400_1569_TaxR.fas
```

***
## Basics
This section explains the basic functionalities of *taxalogue*. Additionally, suggested pipelines and useful tips will be shown.

- [Basic usage](#basic-usage)
  - [download](#download)
  - [classify](#classify)
  - [output](#output)
  - [create](#create)
  - [Modifying the default config](#modifying-the-default-config)
- [General options](#general-options)
  - [--taxon](#--taxon)
  - [--markers](#--markers)
  - [--fast_run](#--fast_run)
  - [--num_threads](#--num_threads)
  - [--version](#--version)
  - [--help](#--help)

***
### Basic Usage
The basic usage looks like: 
```console
bundle exec ruby taxalogue.rb [general_options] [subcommand [subcommand_options]]
```


To get an overview of all general options and all available subcommands use `--help`
```console
bundle exec ruby taxalogue.rb --help
```


If you want to see the available options for a subcommand use  `subcommand --help`:
```console
bundle exec ruby taxalogue.rb filter --help
```


If you want to specify [general options](#general-options) (`--taxon`, `--markers`, `--fast_run`, `num_threads`, `version`) you have to do it right after `bundle exec ruby taxalogue.rb`:
```console
bundle exec ruby taxalogue.rb --taxon Orthoptera
```


All the subcommands and the subcommand options will then come right after it:
```console
bundle exec ruby taxalogue.rb --taxon Orthoptera create --gbol --bold
```


The subcommands associated subcommand options should be listed right after the subcommand:
```console
bundle exec ruby taxalogue.rb --taxon Orthoptera create --gbol --bold filter --taxon_rank species --max_N 2 region -country "Germany"
```
The last command would generate a reference database for the taxon Orthoptera with sequences from BOLD and GBOL. It would only contain sequences with at least species information, that have a maximum of 2 Ns and belong to specimens collected in Germany.
  
***
#### **download**
This command only downloads sequences for the specified taxon and does not do any other thing like classification or filtering etc.. Options can be used to get sequences from all available source databases (BOLD, GBOL and GenBank) or just for example from GBOL and BOLD.

The results will be written into the `downloads` folder:

        ├── downloads/
        │   ├── BOLD/
        │   │   ├── Arthropoda-20210317T1604/
        │   ├── GBOL/
        │   │   ├── GBOL_Dataset_Release-20210128/
        │   ├── NCBIGENBANK/
        │   │   ├── release245/
        │   │   │   ├── inv/
        │   │   │   ├── mam/

Examples:
```console   
## download co1 sequences for Orthoptera with sequences from BOLD, GBOL and GenBank
bundle exec ruby taxalogue.rb -t Orthoptera download --all

## download co1 sequences for Orthoptera with sequences from only BOLD and GBOL
bundle exec ruby taxalogue.rb -t Orthoptera download --bold --gbol
``` 

***
#### **classify**
If you already downloaded sequences with the `create` or `download` subcommand, you could classify these downloads without downloading it again. This is useful if you for example want another version of the database that only allow sequences that are determined until species level. Or you don't want to allow any Ns in the sequences. You could also try a different taxonomy.

If you already downloaded sequences for Arthropoda, you could also generate a subset of only Hymenoptera without having to download Hymenoptera again, since they are already available through the older download. This of course does only work if you already have downloades sequences for your specified taxon or for a higher taxon.

The results will be written into the `results` folder:

        ├── results/
        │   ├── Arthropoda-20210317T1604/

Examples:
```console   
## classify co1 sequences for Hymenoptera with the latest downloads from BOLD, GBOL and GenBank
bundle exec ruby taxalogue.rb -t Orthoptera download --all

## classify co1 sequences for Hymenoptera with the latest downloads from BOLD, GBOL and GenBank and which are determined until the species rank
bundle exec ruby taxalogue.rb -t Hymenoptera download --all filter --taxon_rank species

## classify co1 sequences for Hymenoptera with the latest downloads from BOLD, GBOL and GenBank that do not have Ns
bundle exec ruby taxalogue.rb -t Hymenoptera download --all filter --max_N 0

## classify co1 sequences for Arthropoda with the latest downloads from only BOLD and use the GBIF Bacbkbone Taxonomy to get accepted taxon names
bundle exec ruby taxalogue.rb -t Hymenoptera download --bold taxonomy --gbif_backbone

## classify co1 sequences for Arthropoda with the download folder you specified
bundle exec ruby taxalogue.rb -t Arthropoda \
classify --gbol_dir /home/user/taxalogue/downloads/GBOL/GBOL_Dataset_Release-20210128 \
--bold_dir /home/user/taxalogue/downloads/BOLD/Arthropoda-20210902T1201 \
--genbank_dir /home/user/taxalogue/downloads/NCBIGENBANK/release245
```

***
#### output

        ├── results/                                         * All results will be written in this folder 
        │   ├── Orthoptera-20210903T1100/                    * This is the folder of your current request
        │   │   ├── contaminants/                            * By default possible inveterebrate contaminants are also downloaded
        │   │   │   ├── Wolbachia_output.tsv            
        │   │   │   ├── Wolbachia_output.fas
        │   │   │   ├── Homo_sapiens_output.tsv
        │   │   │   ├── Homo_sapiens_output.tsv
        │   │   ├── gbol_download_info.txt                   * Shows information about successes and failures during the GBOL download 
        │   │   ├── bold_download_info.txt                   * Shows information about successes and failures during the BOLD download
        │   │   ├── ncbi_genbank_download_info.txt           * Shows information about successes and failures during the GenBank download
        │   │   ├── taxalogue.txt                            * Consists of your specified parameters for this taxalogue run
        │   │   ├── Orthoptera_derep_all_output.tsv          * Dereplicated TSV file for Orthoptera with sequences from GBOL, BOLD and GenBank
        │   │   ├── Orthoptera_derep_all_output.fas          * Dereplicated fasta file for Orthoptera with sequences from GBOL, BOLD and GenBank
        │   │   ├── Orthoptera_derep_all_comparison.tsv      * Dereplicated TSV file for Orthoptera with sequences from GBOL, BOLD and GenBank
        │   │   ├── Orthoptera_derep_all_qiime2_taxonomy.txt
        │   │   ├── Orthoptera_derep_all_qiime2_taxonomy.fas
        │   │   ├── Orthoptera_derep_all_kraken2.fas
        │   │   ├── Orthoptera_derep_all_dada2_taxonomy.fas
        │   │   ├── Orthoptera_derep_all_dada2_species.fas
        │   │   ├── Orthoptera_derep_all_sintax.fas
       
***
#### create
**Should only be used for small taxa with few records, since a download failure for millions of records is especially likely for BOLD**

This command creates a barcode database. It will download all sequences belonging to the specified taxon, after that all downloaded files will be parsed and it is checked if a taxon name is present in the chosen taxonomy (default is the NCBI taxonomy). Depending on your used options it might allow the usage of synonyms, or otherwise the accepted name from the NCBI taxonomy will be used. After that the default option is to dereplicate all the sequences and resolve conflicts.

The results will be written into the `results` folder:

        ├── results/
        │   ├── Arthropoda-20210317T1604/


Examples:
```console   
## creates a co1 database for Orthoptera with sequences from BOLD, GBOL and GenBank
bundle exec ruby taxalogue.rb -t Orthoptera create --all

## creates a co1 database for Orthoptera with sequences that have to be at least determined
## to the genus level from BOLD, GBOL and GenBank
bundle exec ruby taxalogue.rb -t Orthoptera create --all filter --taxon_rank genus

## creates a co1 database for Arthropoda with sequences that have to be at least determined
## to the species level and were collected in Germany, Belgium or France from BOLD, GBOL and GenBank
bundle exec ruby taxalogue.rb -t Arthropoda create --all filter --taxon_rank species region --country "Germany;France;Belgium"
```  

***
#### **Modifying the default config**
If *taxalogue* is called without any options it will only use the default values and those that have been specified in the `default_config.yaml` file. The config file can be adopted to your preferences. 

```yaml
:taxon: Arthropoda
:taxon_rank: phylum
:markers: co1
:fast_run: true
:num_threads: 5
:num_cores: 5
:taxonomy:
  :ncbi: true
:derep:
  :last_common_ancestor: false
  :random: false
  :discard: false
  :no_derep: true
:output:
  :table: true
  :fasta: true
  :comparison: true
  :qiime2: false
  :kraken2: false
  :dada2_taxonomy: false
  :dada2_species: false
  :sintax: false
```

***
### General options
#### **--taxon**
The taxa you are able to use depends on the used taxonomy. Taxa names have to be provided in their latinized form without authorship information. At the moment only taxa names for standard ranks are allowed (species, genus, family, order, class, phylum and kingdom). If the taxon is not available, check for any misspelings and if it belongs to the allowed ranks. Available taxa are listed at [NCBI Taxonomy](https://www.ncbi.nlm.nih.gov/taxonomy) or [GBIF](https://www.gbif.org/species/).


#### **--markers**
Currently only co1. default: co1


#### **--fast_run**
Accellerates Taxon comparison. Turn it off with --fast_run false. default: true


#### **--num_threads**
Number of threads for downloads. default: 5


#### **--num_cores**
Number of cores for classification. default: 5


#### **--version**
Shows the used version


#### **--help**
Lists all general options and shows available subcommands. If  `--help` is used after a subcommand than it will show all options for that subbcomand

***
 ## More examples
 
 ### Combinations
 ```console
 ## get all Insecta sequences from Europe with a minimum length of 500 nucleotides and at maximum 2 Ns
 bundle exec ruby taxalogue.rb --taxon Insecta region -k Europe filter --min_length 500 --max_N 2
 
 ## get all Arthropoda sequences from palearctic regions wit a size between 600 and 700 nucleotides and no Ns 
 bundle exec ruby taxalogue.rb --taxon Arthropoda region -biogeographic_realm Palearctic filter --min_length 600 --max_length 700 --max_N 0
 ```
 
 ### Choose a taxon
 ```console
 ## defaults to Arthropoda
 bundle exec ruby taxalogue.rb
 
 ## choose Arthropoda explicitly
 bundle exec ruby taxalogue.rb -t Arthropoda
 
 ## choose Insecta
 bundle exec ruby taxalogue.rb -t Insecta
 ```
 
 ### Choose a taxonomy
 ```console
 ## print available options
bundle exec ruby taxalogue.rb taxonomy -h
 
 ## use GBIF backbone + additional datasets provided by GBIF for taxonomic mapping
 bundle exec ruby taxalogue.rb -t Arthropoda taxonomy --gbif
 
 ## use only the GBIF Backbone taxonomy
 bundle exec ruby taxalogue.rb -t Arthropoda taxonomy --gbif_backbone
 
 ## use NCBI Taxonomy, default
 bundle exec ruby taxalogue.rb -t Arthropoda taxonomy --ncbi
 
 ## use GBIF Backbone and allow synonyms
 bundle exec ruby taxalogue.rb -t Arthropoda taxonomy --gbif_backbone --allow_syonyms

 ## Disable taxonomic harmonization
 bundle exec ruby taxalogue.rb -t Arthropoda taxonomy --unmapped
```

### Filter sequences
```console
## print available options
bundle exec ruby taxalogue.rb filter -h

## no Ns or gaps allowed
bundle exec ruby taxalogue.rb -t Arthropoda filter --max_N 0 --max_G 0

## sequences have a minimum length of 300 nucleotides
bundle exec ruby taxalogue.rb -t Arthropoda filter --min_length 300

## sequences are between 100 and 900 nucleotides long and have at maximum 9 Ns and 3 gaps
bundle exec ruby taxalogue.rb -t Arthropoda filter --min_length 100 --max_length 900 --max_N 9 --max_G 3
```

### Choose sequences by countries or continents

If you want filter the sequences by countries or continents, then only sequences are considered that have this information present. Sequences without this information get discared
```console
## print available options
bundle exec ruby taxalogue.rb region -h

## only sequences from Germany
bundle exec ruby taxalogue.rb -t Arthropoda region -c Germany

## only sequences from Germany, France and Austria
bundle exec ruby taxalogue.rb -t Arthropoda region -c "Germany;France;Austria"

## only sequences from North America
bundle exec ruby taxalogue.rb -t Arthropoda region -k "North America"

## only sequences from North America and Ecuador
bundle exec ruby taxalogue.rb -t Arthropoda region -k "North America" -c Ecuador

## only sequences from North America and Europe
bundle exec ruby taxalogue.rb -t Arthropoda region -k "North America;Europe"
```

### Choose sequences by biogegraphic realms
If you want filter the sequences by biogeographic realms, then only sequences are considered that have latitude and longitude information. Sequences without this information get discarded
```console
## show all available realms
bundle exec ruby taxalogue.rb -B

## sequences from the Palearctic
bundle exec ruby taxalogue.rb -t Arthropoda region -b Palearctic

## sequences from the Palearctic and Nearctic
bundle exec ruby taxalogue.rb -t Arthropoda region -b "Palearctic;Nearctic"
```

### Choose sequences by terrestrial eco zones
If you want filter the sequences by terrestrial eco zones, then only sequences are considered that have latitude and longitude information. Sequences without this information get discared
```console
## show all available terrestrial eco regions
bundle exec ruby taxalogue.rb -E

## sequences from Western European broadleaf forests 
bundle exec ruby taxalogue.rb -t Arthropoda region -e "Western European broadleaf forests"

## sequences from Zambezian coastal flooded savanna and Zambezian flooded grasslands
bundle exec ruby taxalogue.rb -t Arthropoda region -e "Zambezian coastal flooded savanna;Zambezian flooded grasslands"
```


### Choose sequences by custom shape file
If a custom shape file should be used, you need to specify these 3 parameters:

- --custom_shapefile => expects a ESRI shape file. It also expects files with .shx and .dbf extension to be in the same folder
- --custom_shapefile_attribute => attribute name that should be used
- --custom_shapefile_values => values of the attribute on which the filtering should be based

An example run could look like this: 
```console
bundle exec ruby taxalogue.rb region --custom_shapefile downloads/SHAPEFILES/fada_regions/fadaregions.shp --custom_shapefile_attribute name --custom_shapefile_values "Nearctic;Palaearctic"
```
**Since the coordinates from the downloaded sequences are most likely based on the WGS84 coordinate reference system, the custom shapefiles are also expected to be based on WGS84** 
