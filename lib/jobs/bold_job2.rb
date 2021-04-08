# frozen_string_literal: true

class BoldJob2
  attr_reader   :taxon, :markers, :taxonomy, :taxon_name , :result_file_manager, :filter_params, :try_synonyms, :taxonomy_params, :region_params, :params

  HEADER_LENGTH = 1
  BOLD_DIR = Pathname.new('fm_data/BOLD')
  DOWNLOAD_INFO_NAME = "bold_download_info.txt"

  def initialize(taxon:, markers: nil, taxonomy:, result_file_manager:, filter_params: nil, try_synonyms: false, taxonomy_params:, region_params: nil, params: nil)
    @taxon                = taxon
    @taxon_name           = taxon.canonical_name
    @markers              = markers
    @taxonomy             = taxonomy
    @result_file_manager  = result_file_manager
    @filter_params        = filter_params
    @try_synonyms         = try_synonyms
    @taxonomy_params      = taxonomy_params
    @region_params        = region_params
    @root_download_dir    = nil
    @params               = params

    @pending = Pastel.new.white.on_yellow('pending')
    @failure = Pastel.new.white.on_red('failure')
    @success = Pastel.new.white.on_green('success')
    @loading = Pastel.new.white.on_blue('loading')
    @loading_color_char_num = (@loading.size) -'loading'.size

  end

  def run
    already_downloaded_dir = BoldDownloadCheckHelper.ask_user_about_download_dirs(params)
    if already_downloaded_dir

      begin
        fm_from_md_name         = already_downloaded_dir + '.download_file_managers.dump'
        fm_from_md              = Marshal.load(File.open(fm_from_md_name, 'rb').read)
        download_file_managers  = fm_from_md

        # _create_download_info_for_result_dir(already_downloaded_dir)
        DownloadCheckHelper.create_download_info_for_result_dir(already_downloaded_dir: already_downloaded_dir, result_file_manager: result_file_manager, source: self.class)
      rescue StandardError => e
        puts "Directory could not be used, starting download"
        sleep 2

        download_file_managers = dload
        DownloadCheckHelper.write_marshal_file(dir: BOLD_DIR + @root_download_dir, data: download_file_managers, file_name: '.download_file_managers.dump')
        DownloadCheckHelper.write_marshal_file(dir: BOLD_DIR + @root_download_dir, data: taxon, file_name: '.taxon_object.dump')
      end
    else

      download_file_managers  = dload
      DownloadCheckHelper.write_marshal_file(dir: BOLD_DIR + @root_download_dir, data: download_file_managers, file_name: '.download_file_managers.dump')
      DownloadCheckHelper.write_marshal_file(dir: BOLD_DIR + @root_download_dir, data: taxon, file_name: '.taxon_object.dump')
    end
    
    _classify_downloads(download_file_managers: download_file_managers)
    # _classify_downloads(download_file_managers: nil)
    
    return result_file_manager
    # _write_result_files(root_node: root_node, fmanagers: fmanagers)
  end

  def _create_download_info_for_result_dir(already_downloaded_dir)
    data_dl_info_public_name = already_downloaded_dir + 'download_info.txt'
    data_dl_info_hidden_name = already_downloaded_dir + '.download_info.txt'

    result_dl_info_public_name = result_file_manager.dir_path + 'download_info.txt'
    result_dl_info_hidden_name = result_file_manager.dir_path + '.download_info.txt'

    dl_info_public = File.open(data_dl_info_public_name).read
    dl_info_hidden = File.open(data_dl_info_hidden_name).read

    dl_info_public.gsub!(/^corresponding result directory:.*$/, "corresponding data directory: #{already_downloaded_dir.to_s}")
    dl_info_hidden.gsub!(/^corresponding result directory:.*$/, "corresponding data directory: #{already_downloaded_dir.to_s}")
    
    File.open(result_dl_info_public_name, 'w') { |f| f.write(dl_info_public) }
    File.open(result_dl_info_hidden_name, 'w') { |f| f.write(dl_info_hidden) }
  end

  def _download_response(downloader:, file_path:)
    begin 
      downloader.run
      return :empty_file if File.empty?(file_path)
      return :server_offline if _server_is_offline(file_path)
    rescue Net::ReadTimeout
      return :read_timeout
    rescue Net::OpenTimeout
      return :open_timeout
    rescue SocketError
      return :socket_error
    rescue
      return :other_error
    end

    return :success
  end

  def dload
    root_node = Tree::TreeNode.new(taxon_name, [taxon, @pending, 'pending'])
    num_of_ranks = GbifTaxonomy.possible_ranks.size
    reached_genus_level = false
    fmanagers = []
    rest_taxa = Hash.new
    num_threads = 5

    num_of_ranks.times do |i|
      _print_download_progress_report(root_node: root_node, rank_level: i)

      Parallel.map(root_node.entries, in_threads: num_threads) do |node|
        next unless node.content[1] == @pending

        config = _create_config(node: node)

        file_manager = config.file_manager
        file_manager.create_dir
        
        @root_download_dir = file_manager.base_dir.basename if node.is_root?

        stats_file_path = file_manager.dir_path + "#{node.name}_stats.json"
        stats_downloader = HttpDownloader2.new(address: _bold_stats_api(node.name), destination: stats_file_path)
        no_stats_file = nil

        stats_file_path = file_manager.dir_path + "#{node.name}_stats.json"
        rank_status = _get_rank_status(node.name, stats_file_path, reached_genus_level)

        node.content[1] = @loading
        node.content[2] = 'loading'
        file_manager.status = 'loading'

        ## skip since download never succeeds due to too many records or other reasons
        if rank_status == :no_records || rank_status == :too_many_records || rank_status == :failing_taxon
          node.content[1] = @failure
          node.content[2] = rank_status.to_s
          file_manager.status = 'failure'
          fmanagers.push(file_manager)
          _print_download_progress_report(root_node: root_node, rank_level: i)
          next
        end


        downloader = config.downloader.new(config: config)
        _print_download_progress_report(root_node: root_node, rank_level: i)
        download_response = _download_response(downloader: downloader, file_path: file_manager.file_path)
        
        if download_response == :success
          node.content[1] = @success
          node.content[2] = download_response.to_s
          file_manager.status = 'success'
          sleep 1

        elsif download_response == :empty_file
          node.content[1] = @failure
          node.content[2] = download_response.to_s
          file_manager.status = 'failure'
          sleep 5

        elsif download_response == :read_timeout
          if reached_genus_level
            3.times do
              sleep 5
              download_response = _download_response(downloader: downloader, file_path: file_manager.file_path)
              
              break if download_response == :success
            end
  
            if download_response == :success
              node.content[1] = @success
              node.content[2] = download_response.to_s
              file_manager.status = 'success'
            else
              node.content[1] = @failure
              node.content[2] = download_response.to_s
              file_manager.status = 'failure'
            end
          else
            node.content[1] = @failure
            node.content[2] = download_response.to_s
            file_manager.status = 'failure'
          end

        elsif download_response == :open_timeout || download_response == :server_offline || download_response == :socket_error || download_response == :other_error 
          3.times do
            sleep 120
            download_response = _download_response(downloader: downloader, file_path: file_manager.file_path)
            
            break if download_response == :success
          end

          if download_response == :success
            node.content[1] = @success
            node.content[2] = download_response.to_s
            file_manager.status = 'success'
          else
            node.content[1] = @failure
            node.content[2] = download_response.to_s
            file_manager.status = 'failure'
          end
        end

        fmanagers.push(file_manager)

        _print_download_progress_report(root_node: root_node, rank_level: i)
      end

      break if reached_genus_level
      # break if i == 2

      failed_nodes = root_node.find_all { |node| node.content[1] == @failure && node.is_leaf? }
      failed_nodes.each do |failed_node|
        node_record                     = failed_node.content.first
        node_name                       = failed_node.name
        index_of_rank                   = GbifTaxonomy.possible_ranks.index(node_record.taxon_rank)
        index_of_lower_rank             = index_of_rank - 1
        reached_genus_level             = true if index_of_lower_rank == 1
        taxon_rank_to_try               = GbifTaxonomy.possible_ranks[index_of_lower_rank]
        
        taxa_records_and_names_to_try = nil
        if taxonomy_params[:gbif] || taxonomy_params[:gbif_backbone]
          taxa_records_and_names_to_try   = GbifTaxonomy.taxa_names_for_rank(taxon: node_record, rank: taxon_rank_to_try)
        
        elsif taxonomy_params[:ncbi]
          taxa_records_and_names_to_try   = NcbiTaxonomy.taxa_names_for_rank(taxon: node_record, rank: taxon_rank_to_try)
        
        else
          taxa_records_and_names_to_try   = NcbiTaxonomy.taxa_names_for_rank(taxon: node_record, rank: taxon_rank_to_try)
        
        end


        next if taxa_records_and_names_to_try.nil?


        ## TODO: does not include taxa with 0 records
        if _needs_rest_download(failed_node.content[2])
          config = _create_config(node: failed_node)

          file_manager = config.file_manager
          rest_path = file_manager.dir_path + "#{failed_node.name}_REST.tsv"
          copy_of_taxa_records_and_names_to_try = taxa_records_and_names_to_try.clone

          rest_query = _rest_query(failed_node.name, copy_of_taxa_records_and_names_to_try)
          downloader = HttpDownloader2.new(address: rest_query, destination: rest_path)

          ## request too long.. over 2k chars igth cause problems
          ## TODO: NEXT
          # <html>
          # <head><title>414 Request-URI Too Large</title></head>
          # <body bgcolor="white">
          # <center><h1>414 Request-URI Too Large</h1></center>
          # <hr><center>nginx</center>
          # </body>
          # </html>

          ## request uri needs to be smaller tha 8190

          # "http://www.boldsystems.org/index.php/API_Public/combined?taxon=Carabidae|-Apotomus|-Aptinus|-Brachinus|-Mastax|-Pheropsophus|-Styphlodromus|-Styphlomerus|-Crepidogaster|-Acallistus|-Bountya|-Broscodera|-Broscosoma|-Broscus|-Brullea|-Chylnus|-Craspedonotus|-Creobius|-Diglymma|-Mecodema|-Metaglymma|-Miscodera|-Oregus|-Percolestus|-Percosoma|-Promecoderus|-Zacotus|-Aplothorax|-Australodrepa|-Callisthenes|-Callitropa|-Calosoma|-Camedula|-Campalita|-Carabomimus|-Carabomorphus|-Castrida|-Charmosta|-Chrysostigma|-Ctenosta|-Microcallisthenes|-Carabus|-Ceroglossus|-Cychropsis|-Cychrus|-Scaphinotus|-Sphaeroderus|-Maoripamborus|-Pamborus|-Antennaria|-Bennigsenium|-Brasiella|-Caledonica|-Callytron|-Calomera|-Calyptoglossa|-Cenothyla|-Cephalota|-Cheilonycha|-Cheiloxya|-Cicindela|-Cylindera|-Distipsidera|-Dromica|-Eucallia|-Eurymorpha|-Euzona|-Habrodera|-Habroscelimorpha|-Heptodonta|-Hypaetha|-Jansenia|-Lophyra|-Microthylax|-Myriochila|-Neocicindela|-Odontocheila|-Opilidia|-Oxycheila|-Oxygonia|-Pentacomia|-Peridexia|-Physodeutera|-Polyrhanis|-Pometon|-Prothyma|-Prothymidia|-Pseudoxycheila|-Stenocosmia|-Sumlinia|-Therates|-Waltherhornia|-Zecicindela|-Ctenostoma|-Neocollyris|-Pogonostoma|-Tricondyla|-Manticora|-Amblycheila|-Aniara|-Australicapitona|-Grammognatha|-Megacephala|-Metriocheila|-Omus|-Phaeoxantha|-Picnochile|-Platychile|-Pseudotetracha|-Tetracha|-Polistichus|-Blethisa|-Diacheila|-Elaphrus|-Gehringia|-Abacetus|-Abacidus|-Cerabilia|-Cyrtomoscelis|-Inkosa|-Metabacetus|-Oxycrepis|-Pediomorphus|-Zeodera|-Diachromus|-Anthia|-Cypholoba|-Catapiesis|-Cnemalobus|-Calophaena|-Ctenodactyla|-Leptotrachelus|-Plagiotelum|-Teukrus|-Desera|-Drypta|-Ancystroglossus|-Galerita|-Planetes|-Trichognathus|-Acinopus|-Acupalpus|-Afromizonus|-Agonoleptus|-Amblygnathus|-Amblystomus|-Amphasia|-Anisodactylus|-Anthracus|-Athrostictus|-Aulacoryssus|-Axinotoma|-Bradybaenus|-Bradycellus|-Carterus|-Cenogmus|-Coleolissus|-Crasodactylus|-Cratacanthus|-Cryptophonus|-Daptus|-Dicheirotrichus|-Dicheirus|-Discoderus|-Ditomus|-Dixus|-Egadroma|-Eocarterus|-Euryderus|-Euthenarus|-Geopinus|-Gnathaphanus|-Graniger|-Harpalus|-Hartonymus|-Hyparpalus|-Hypharpax|-Incisophonus|-Lecanomerus|-Nesarpalus|-Nornalupia|-Notiobia|-Odontocarus|-Ophonus|-Parophonus|-Pelmatellus|-Philodes|-Phorticosomus|-Piosoma|-Platymetopus|-Pogonodaptus|-Polpochila|-Pseudognathaphanus|-Scybalicus|-Selenophorus|-Semiophonus|-Stenolophus|-Stenomorphus|-Trichotichnus|-Tschitscherinellus|-Aenigma|-Dicranoglossus|-Gigadaema|-Helluomorphoides|-Macrocheilus|-Omphra|-Pogonoglossus|-Dinopelma|-Hexagonia|-Metius|-Morion|-Moriosomus|-Orthogonius|-Craspedophorus|-Dischissus|-Micrixys|-Microschemus|-Panagaeus|-Tefflus|-Eripus|-Pelecium|-Pentagonica|-Scopodes|-Adelotopus|-Pseudomorpha|-Sphallomorpha|-Abaris|-Abax|-Abropus|-Acanthoferonia|-Ancholeus|-Aporesthus|-Aristochroa|-Aulacopodus|-Caelostomus|-Castelnaudia|-Colpodes|-Conchitella|-Cyclotrachelus|-Eucamptognathus|-Eudromus|-Euplynes|-Eutrichopus|-Gastrellarius|-Henrotius|-Hybothecus|-Leiradira|-Lesticus|-Lophoglossus|-Loxodactylus|-Megadromus|-Molopidius|-Molops|-Myas|-Nirmala|-Notonomus|-Nurus|-Orthomus|-Oscadytes|-Paniestichus|-Parhypates|-Pedius|-Percus|-Piesmus|-Platycaelus|-Poecilus|-Pseudamara|-Pseudoceneus|-Pterostichus|-Sarticus|-Setalimorphus|-Speomolops|-Stereocerus|-Stomis|-Styracoderus|-Tanythrix|-Tapinopterus|-Trichosternus|-Trigonognatha|-Trigonotoma|-Typhlochoromus|-Wolltinerfia|-Zariquieya|-Elaphropus|-Paratachys|-Porotachys|-Tachys|-Amara|-Zabrus|-Acrogenys|-Ildobates|-Mischocephalus|-Parazuphium|-Pseudaptinus|-Thalpius|-Zuphium|-Gomerina|-Paraeutrichopus|-Aephnidius|-Sarothrocrepis|-Tetragonoderus|-Graphipterus|-Anchonoderus|-Asklepia|-Calybe|-Euphorticus|-Homethes|-Lachnophorus|-Actenonyx|-Agra|-Anomotarus|-Antimerina|-Apenes|-Apristus|-Arsinoe|-Aspasiola|-Axinopalpus|-Brachyctis|-Calleida|-Callidiola|-Calodromius|-Catascopus|-Celaenephes|-Coptodera|-Coptoptera|-Cylindrocranius|-Cymindis|-Cymindoidea|-Demetrias|-Demetrida|-Dromius|-Endynomena|-Euproctinus|-Eurydera|-Hyboptera|-Hystrichopus|-Inna|-Lachnoderma|-Lebia|-Lia|-Lionychus|-Menarus|-Microlestes|-Mimodromius|-Mochtherus|-Mormolyce|-Nemotarsus|-Onota|-Paradromius|-Parena|-Peliocypas|-Pericalus|-Philophlaeus|-Philophuga|-Philorhizus|-Physodera|-Plochionus|-Pristacrus|-Pseudotrechus|-Serrimargo|-Sinurus|-Somotrichus|-Stenocallida|-Stenognathus|-Stenotelus|-Syntomus|-Tecnophilus|-Thysanotus|-Anaulacus|-Masoreus|-Clarencia|-Colliuris|-Cosnania|-Dicraspeda|-Lasiocera|-Odacantha|-Ophionea|-Stenidia|-Diploharpus|-Perigona|-Ripogena|-Callistus|-Chlaenius|-Badister|-Dicaelus|-Dicrochile|-Diplocheila|-Eutogeneius|-Lacordairia|-Lestignathus|-Licinus|-Adelopomorpha|-Anatrichis|-Dercylus|-Lachnocrepis|-Oodes|-Stenocrepis|-Loricera|-Cymbionotum|-Amarotypus|-Antarctonomus|-Lissopterus|-Monolobus|-Pseudomigadops|-Leistus|-Nebria|-Oreonebria|-Notiophilus|-Opisthius|-Omophron|-Metrius|-Anentmetus|-Entomoantyx|-Filicerozaena|-Goniotropis|-Inflatozaena|-Itamus|-Mystropomus|-Ozaena|-Pachyteles|-Physea|-Platycerozaena|-Proozaena|-Pseudozaena|-Serratozaena|-Sphaerostylus|-Tachypeles|-Tropopsis|-Arthropterus|-Carabidomemnus|-Cerapterus|-Ceratoderus|-Edaphopaussus|-Eohomopterus|-Euplatyrhopalus|-Granulopaussus|-Heteropaussus|-Homopterus|-Hylopaussus|-Lebioderus|-Paussus|-Pentaplatarthrus|-Platyrhopalopsis|-Platyrhopalus|-Protopaussus|-Agonum|-Anchomenus|-Atranus|-Blackburnia|-Calathidius|-Ctenognathus|-Dicranoncus|-Dyscolus|-Glyptolenus|-Incagonum|-Liagonum|-Limodromus|-Metacolpodes|-Neomegalonychus|-Notagonum|-Olisthopus|-Oxypselaphus|-Paranchus|-Platynus|-Rhadine|-Sericoda|-Tanystoma|-Acalathus|-Amaroschema|-Anchomenidius|-Calathus|-Dolichus|-Laemostenus|-Licinopsis|-Lindrothius|-Miquihuana|-Platyderus|-Pristosia|-Synuchidius|-Synuchus|-Thermoscelis|-Xestopus|-Dalyat|-Promecognathus|-Meonis|-Amblytelus|-Mecyclothorax|-Melisodera|-Laccocenus|-Nomius|-Psydrus|-Raphetis|-Tropopterus|-Sitaphe|-Clinidium|-Dhysores|-Omoglymmius|-Rhysodes|-Akephorus|-Antireicheia|-Ardistomis|-Clivina|-Dyschiriodes|-Dyschirius|-Paraclivina|-Reicheia|-Schizogenius|-Trilophidius|-Typhloreicheia|-Carenum|-Distichus|-Pasimachus|-Scarites|-Siagona|-Lusotyphlus|-Microcharidius|-Typhlocharis|-Andinodontis|-Argentinatachoides|-Bembidarenas|-Tasmanitachoides|-Amerizus|-Anillinus|-Anillodes|-Anillus|-Anomotachys|-Argiloborus|-Asaphidion|-Batesiana|-Bembidion|-Binaghites|-Caeconannus|-Erwiniana|-Geocharidius|-Geocharis|-Gouleta|-Hypotyphlus|-Iberanillus|-Illaphanus|-Kiwitachys|-Lionepha|-Lymnastis|-Meotachys|-Micratopus|-Microdipnus|-Microtyphlus|-Mioptachys|-Nesamblyops|-Nothoderis|-Ocys|-Orthotyphlus|-Orzolina|-Parvocaecus|-Pelonomites|-Pericompsus|-Philipis|-Polyderis|-Pseudanillus|-Rhegmatobius|-Scotodipnus|-Serranillus|-Sinechostictus|-Tachyta|-Tachyura|-Apatrobus|-Apenetretus|-Archipatrobus|-Dimorphopatrobus|-Diplous|-Lissopogonus|-Parapenetretus|-Patrobus|-Penetretus|-Platidiolus|-Platypatrobus|-Qiangopatrobus|-Diplochaetus|-Pogonistes|-Pogonus|-Sirdenus|-Thalassotrechus|-Chaltenia|-Phrypeus|-Sinozolus|-Adriaphaenops|-Aepopsis|-Agonotrechus|-Agostinia|-Allegrettia|-Ameroduvalius|-Anophthalmus|-Aphaenopidius|-Aphaenops|-Apoduvalius|-Apoplotrechus|-Arctaphaenops|-Blemus|-Boldoriella|-Bothynotrechus|-Cnides|-Cyphotrechodes|-Darlingtonea|-Doderotrechus|-Duvalius|-Epaphiopsis|-Epaphius|-Eutrechopsis|-Geotrechus|-Homaloderodes|-Hydraphaenops|-Iberotrechus|-Italaphaenops|-Jeannelius|-Kenodactylus|-Laosaphaenops|-Lessinodytes|-Mexitrechus|-Mimotrechus|-Neaphaenops|-Nelsonites|-Neotrechus|-Nototrechus|-Omalodera|-Orotrechus|-Oxytrechus|-Pachydesus|-Paraphaenops|-Paratrechodes|-Paratrechus|-Perileptus|-Pheggomisetes|-Pseudanophthalmus|-Pseudocnides|-Sardaphaenops|-Speotrechus|-Sporades|-Tasmanorites|-Thalassophilus|-Trechiella|-Trechimorphus|-Trechinotus|-Trechisibus|-Trechistus|-Trechobembix|-Trechoblemus|-Trechodes|-Trechosiella|-Trechus|-Trichaphaenops|-Tropidotrechus|-Typhlotrechus|-Xenotrechus|-Merizodus|-Oopterus|-Pseudoopterus|-Sloaneana|-Anoplogenius|-Argutoridius|-Askalaphium|-Aspidoglossa|-Baripus|-Blennidus|-Brachygnathus|-Brachyodes|-Bronislavia|-Cascellius|-Cheiloxia|-Cicindis|-Cyrtolaus|-Dioryche|-Enceladus|-Eucamaragnathus|-Eucheila|-Eurycoleus|-Eurynebria|-Geobius|-Geoscaptus|-Gynandropus|-Helluodes|-Helluomorpha|-Hiletus|-Lebidia|-Lelis|-Microcosmodes|-Migadops|-Nanodiodes|-Neoaulacoryssus|-Nyctosyles|-Oceanella|-Onypterygia|-Oodinus|-Oosoma|-Paropisthius|-Peronomerus|-Phloeoxena|-Pseudabarys|-Simous|-Somoplatus|-Styphromerus|-Trichognatus|-Trichopselaphus|-Trirammatus|-Whiteheadiana&format=tsv"


          puts 'startin rest download for:'
          puts failed_node.name

          ## if the records will be more than approx 100k there might be no success
          ## no encounters atm since the overlap of NcbiTaxonomy and BOLD is great
          download_response = _download_response(downloader: downloader, file_path: rest_path)
        end


        added_names = []
        taxa_records_and_names_to_try.each do |record_and_name|

          record  = record_and_name.first
          name    = record_and_name.last
          
          next if TaxonHelper.is_extinct?(name)
          next if added_names.include?(name) # prevent breaking if name occurs multiple times maybe due to wrong backbone

          failed_node << Tree::TreeNode.new(name, [record, @pending, 'pending'])
          added_names.push(name)
        end
      end
    end

    # _write_result_files(root_node: root_node, fmanagers: fmanagers)
    # root_node.each do |node|
    #   pp node
    #   puts '-----'
    # end
    # exit


    dl_path_public = Pathname.new(BoldConfig::DOWNLOAD_DIR + @root_download_dir + DOWNLOAD_INFO_NAME)
    dl_path_hidden = Pathname.new(BoldConfig::DOWNLOAD_DIR + @root_download_dir + ".#{DOWNLOAD_INFO_NAME}")
    rs_path_public = Pathname.new(result_file_manager.dir_path + DOWNLOAD_INFO_NAME)
    rs_path_hidden = Pathname.new(result_file_manager.dir_path + ".#{DOWNLOAD_INFO_NAME}")
    _write_download_info(paths: [dl_path_public, dl_path_hidden, rs_path_public, rs_path_hidden], root_node: root_node)

    failures = DownloadInfoParser.get_download_failures(dl_path_hidden)
    
    unless failures.empty?
      ## maybe directly try to download again?
    end
    return fmanagers
  end

  def _write_download_info(paths:, root_node:)

    paths.each do |path|
      file = File.open(path, 'w')

      root_node_copy = root_node.detached_subtree_copy
      root_node_copy.each do |node|
        node.content = node.content.last
      end

      basename = path.basename.to_s
      if basename.starts_with?('.')
        hash = root_node_copy.to_h
        json_hash = hash.to_json

        file.puts(json_hash)
      else
        root_node_copy.print_tree(level = root_node.node_depth, max_depth = nil, block = lambda { |node, prefix| file.puts "#{prefix} #{node.name}".ljust(30) + " #{node.content}" })
      end

      real_failed_nodes = root_node.find_all { |node| node.is_leaf? && _real_failure(node.content[2]) }
      success = real_failed_nodes.empty? ? 'true' : 'false'

      if path.descend.first.to_s == 'results'
        file.puts
        file.puts "corresponding data directory: #{(BOLD_DIR + @root_download_dir).to_s}"
      else
        file.puts
        file.puts "corresponding result directory: #{result_file_manager.dir_path.to_s}"
      end

      file.puts
      file.puts "success: #{success}"
      file.rewind
    end
  end

  def _real_failure(node_content)
    node_content == 'server_offline' || node_content == 'read_timeout' || node_content == 'open_timeout' || node_content == 'socket_error' || node_content == 'other_error' 
  end

  def _needs_rest_download(node_content)
    node_content == 'server_offline' || node_content == 'read_timeout' || node_content == 'open_timeout' || node_content == 'socket_error' || node_content == 'other_error' || node_content == 'too_many_records' || node_content == 'failing_taxon'
  end

  def _rest_query(failed_taxon, taxa_to_exclude)

    base = 'http://www.boldsystems.org/index.php/API_Public/combined?'
    

    max_query_size = 8190 ## apache default
    max_query_size -= 120 ## minus base + additional query
    taxa = []
    taxa_to_exclude.each_with_index do |taxon, i|
      taxon_name = taxon.last
      excluded_taxon_name = taxon_name.split.unshift('-').join('')
      taxa.push(excluded_taxon_name)
      char_count = taxa.join.size + (i+1) ## add # | delimiter
      if char_count >= max_query_size
        taxa.pop
        break
      end
    end

    excluded_taxa_string = taxa.join('|')
    query = excluded_taxa_string.prepend("taxon=")
    query = query.concat("|#{failed_taxon}")
    query = query.concat('&format=tsv')
    
    if query.size >= max_query_size
      ## TODO:
    end
    query = base.dup.concat(query)

    return query
  end

  def _safe_download(node:, file_manager:, root_node:, i:)
    begin
      node.content[1] = @loading
      file_manager.status = 'loading'
      _print_download_progress_report(root_node: root_node, rank_level: i)
      downloader.run
      
      if File.empty?(file_manager.file_path)
        node.content[1] = @failure
        file_manager.status = 'failure'
      else
        if _server_is_offline(file_manager.file_path)
          succesfull_try_after_offline_server = false
          3.times do
            sleep(2.minutes)
            downloader.run
            unless _server_is_offline(file_manager.file_path)
              succesfull_try_after_offline_server =  true
              break
            end
          end

          if succesfull_try_after_offline_server
            node.content[1] = @success
            file_manager.status = 'success'
          else 
            node.content[1] = @failure
            file_manager.status = 'failure'
          end
        else
          node.content[1] = @success
          file_manager.status = 'success'
        end
      end
    rescue Net::ReadTimeout
      node.content[1] = @failure
      file_manager.status = 'failure'
    end

    fmanagers.push(file_manager)
    _print_download_progress_report(root_node: root_node, rank_level: i)
  end

  def download_files
    root_node                           = Tree::TreeNode.new(taxon_name, [taxon, @pending])
    ## TODO: same for NcbiTaxonomy
    num_of_ranks                        = GbifTaxonomy.possible_ranks.size
    reached_family_level                = false
    reached_genus_level                 = false
    fmanagers                           = []
    num_threads = 2
    
    num_of_ranks.times do |i|
      
      _print_download_progress_report(root_node: root_node, rank_level: i)
      
      Parallel.map(root_node.entries, in_threads: num_threads) do |node|
        next unless node.content[1] == @pending

        config = _create_config(node: node)

        file_manager = config.file_manager
        file_manager.create_dir

        downloader = config.downloader.new(config: config)
        # downloader.extend(MiscHelper.constantize("Printing::#{downloader.class}"))

        begin
          node.content[1] = @loading
          file_manager.status = 'loading'
          _print_download_progress_report(root_node: root_node, rank_level: i)
          downloader.run
          if File.empty?(file_manager.file_path)
            if try_synonyms
              synonym_file_manager = _download_synonym(node: node)
              if synonym_file_manager && synonym_file_manager.status == 'success'
                file_manager = synonym_file_manager 
                node.content[1] = @success
              else
                node.content[1] = @failure
                file_manager.status = 'failure'
              end
            else
              node.content[1] = @failure
              file_manager.status = 'failure'
            end
          else
            if _server_is_offline(file_manager.file_path)
              succesfull_try_after_offline_server = false
              3.times do
                sleep(2.minutes)
                downloader.run
                unless _server_is_offline(file_manager.file_path)
                  succesfull_try_after_offline_server =  true
                  break
                end
              end

              if succesfull_try_after_offline_server
                node.content[1] = @success
                file_manager.status = 'success'
              else 
                node.content[1] = @failure
                file_manager.status = 'failure'
              end
            else
              node.content[1] = @success
              file_manager.status = 'success'
            end
          end
        rescue Net::ReadTimeout
          node.content[1] = @failure
          file_manager.status = 'failure'
        end

        fmanagers.push(file_manager)
        _print_download_progress_report(root_node: root_node, rank_level: i)
      end
      
      break if reached_genus_level
      # break if i == 2

      failed_nodes = root_node.find_all { |node| node.content[1] == @failure && node.is_leaf? }
      failed_nodes.each do |failed_node|
        node_record                     = failed_node.content.first
        node_name                       = failed_node.name
        index_of_rank                   = GbifTaxonomy.possible_ranks.index(node_record.taxon_rank)
        index_of_lower_rank             = index_of_rank - 1
        # reached_family_level            = true if index_of_lower_rank == 2
        reached_genus_level             = true if index_of_lower_rank == 1
        taxon_rank_to_try               = GbifTaxonomy.possible_ranks[index_of_lower_rank]
        
        taxa_records_and_names_to_try = nil
        if taxonomy_params[:gbif] || taxonomy_params[:gbif_backbone]
          taxa_records_and_names_to_try   = GbifTaxonomy.taxa_names_for_rank(taxon: node_record, rank: taxon_rank_to_try)
        
        elsif taxonomy_params[:ncbi]
          taxa_records_and_names_to_try   = NcbiTaxonomy.taxa_names_for_rank(taxon: node_record, rank: taxon_rank_to_try)
        
        else
          taxa_records_and_names_to_try   = NcbiTaxonomy.taxa_names_for_rank(taxon: node_record, rank: taxon_rank_to_try)
        
        end

        next if taxa_records_and_names_to_try.nil?
        added_names = []
        taxa_records_and_names_to_try.each do |record_and_name|

          record  = record_and_name.first
          name    = record_and_name.last
          
          next if TaxonHelper.is_extinct?(name)
          next if added_names.include?(name) # prevent breaking if name occurs multiple times maybe due to wrong backbone

          failed_node << Tree::TreeNode.new(name, [record, @pending])
          added_names.push(name)
        end
      end
    end

    _write_result_files(root_node: root_node, fmanagers: fmanagers)


    return fmanagers
  end

  def _print_download_progress_report(root_node:, rank_level:)
    root_copy = root_node.detached_subtree_copy

    system("clear") || system("cls")
    puts

    nodes_currently_loading = root_copy.find_all { |node| node.content[1] == @loading && node.is_leaf? }
    return if nodes_currently_loading.nil?
    
    if rank_level <= 1
      root_copy.print_tree(level = root_copy.node_depth, max_depth = nil, block = lambda { |node, prefix| puts "#{prefix} #{node.name}".ljust(30) + " #{node.content[1]}" })
      _print_legend
      return
    end

    already_printed_parents = []
    loading_parent_nodes    = []
    nodes_currently_loading.each { |node| loading_parent_nodes.push(node.parentage); loading_parent_nodes.flatten! }
    
    root_copy.print_tree(level = root_copy.node_depth, max_depth = 1, block = lambda { |node, prefix| puts loading_parent_nodes.include?(node) ? "#{prefix} #{Pastel.new.white.on_blue(node.name)}".ljust(30 + @loading_color_char_num) + " #{node.content[1]}" : "#{prefix} #{node.name}".ljust(30) + " #{node.content[1]}" })
    
    puts
    puts "currently loading:"
    nodes_currently_loading.each do |loading_node|
      not_loading_nodes = loading_node.parent.find_all { |node| node.content[1] != @loading && node.is_leaf? }
      not_loading_nodes.each do |not_loading_node|
        loading_node.parent.remove!(not_loading_node)
      end

      if already_printed_parents.include?(loading_node.parent.name)
        next
      else
        loading_node.parent.print_tree(level = loading_node.parent.node_depth, max_depth = nil, block = lambda { |node, prefix| puts "#{prefix} #{node.name}".ljust(30) + " #{node.content[1]}" })
      end

      already_printed_parents.push(loading_node.parent.name)
    end
    _print_legend
  end

  def _print_legend
    puts
    puts @pending.ljust(20) + "waits until a downloader is avalaible"
    puts @loading.ljust(20) + "downloads records"
    puts @failure.ljust(20) + "download was not successful, often due to too many records, tries lower ranks soon"
    puts @success.ljust(20) + "download was successful"
    puts
  end

  def _create_config(node:)
    if node.parentage
      parent_dir    = _get_parentage_as_dir_structure(node)
      config        = BoldConfig.new(name: node.name, markers: markers, parent_dir: parent_dir)
    else
      config        = BoldConfig.new(name: node.name, markers: markers, is_root: true)
    end
  end

  def _get_rest_of_taxon_query



  end

  def _get_parentage_as_dir_structure(node)
    if node.parentage
      parent_names  = []
      node.parentage.each do |parent_node|
        parent_node.is_root? ? parent_names.push((@root_download_dir + parent_node.name)) : parent_names.push(Pathname.new(parent_node.name))
      end
      # parent_dir = parent_names.reverse.join('/')
      begin
        parent_dir = parent_names.reverse.inject(:+)
      rescue TypeError
      end
      
      return parent_dir
    end
  end

  ## TODO: same for NcbiTaxonomy
  def _download_synonym(node:)
    syn = Synonym.new(accepted_taxon: node.content.first, sources: [GbifTaxonomy])
    file_manager = nil

    syn.synonyms.each do |synonym|
      parent_dir      = _get_parentage_as_dir_structure(node)
      synonym_config  = BoldConfig.new(name: synonym.canonical_name, markers: markers, parent_dir: parent_dir)
      
      file_manager    = synonym_config.file_manager
      file_manager.create_dir
      
      synonym_downloader  = synonym_config.downloader.new(config: synonym_config)
      
      begin
        synonym_downloader.run
        if File.empty?(file_manager.file_path)
          file_manager.status = 'failure'
        else
          file_manager.status = 'success'
          break
        end
      rescue Net::ReadTimeout
        file_manager.status = 'failure'
      end
    end

    if file_manager && file_manager.status == 'success'
      return file_manager
    else  
      return nil
    end
  end

  def _write_result_files(root_node:, fmanagers:)
    root_dir              = fmanagers.select { |m| m.name == root_node.name }.first
    # merged_download_file  = File.open(root_dir.dir_path + "#{root_dir.name}_merged.tsv", 'w') 
    download_info_file    = File.open(root_dir.dir_path + "#{root_dir.name}_download_info.tsv", 'w') 
    # download_successes    = fmanagers.select { |m| m.status == 'success' }

    # OutputFormat::MergedBoldDownload.write_to_file(file: merged_download_file, data: download_successes, header_length: HEADER_LENGTH, include_header: true)
    OutputFormat::DownloadInfo.write_to_file(file: download_info_file, fmanagers: fmanagers)
  end

  def _classify_downloads(download_file_managers:)
    # bold_classifier   = BoldImporter.new(fast_run: false, file_name: Pathname.new('/home/nnoll/phd/trait_db/notes/coll.tsv'), query_taxon_object: taxon, file_manager: result_file_manager, filter_params: filter_params, markers: markers, taxonomy_params: taxonomy_params, region_params: region_params)
    # bold_classifier.run ## result_file_manager creates new files and will push those into internal array
    
    download_file_managers.each do |download_file_manager|
      next unless download_file_manager.status == 'success'
      next unless File.file?(download_file_manager.file_path)

	    bold_classifier   = BoldImporter.new(fast_run: false, file_name: download_file_manager.file_path, query_taxon_object: taxon, file_manager: result_file_manager, filter_params: filter_params, markers: markers, taxonomy_params: taxonomy_params, region_params: region_params)
      bold_classifier.run ## result_file_manager creates new files and will push those into internal array
    end
  end

  def _merge_results
    FileMerger.run(file_manager: result_file_manager, file_type: OutputFormat::Tsv)
    FileMerger.run(file_manager: result_file_manager, file_type: OutputFormat::Fasta)
    FileMerger.run(file_manager: result_file_manager, file_type: OutputFormat::Comparison)
  end

  def _server_is_offline(file_path)
    File.open(file_path, &:gets) =~ /<!DOCTYPE html>/
  end

  def _bold_stats_api(name)
    "http://www.boldsystems.org/index.php/API_Public/stats?taxon=#{name}&format=json"
  end

  def _get_rank_status(name, file_path, reached_genus_level)
    failing_taxa = ['Arthropoda', 'Insecta', 'Arachnida', 'Collembola', 'Malacostraca', 'Carabidae']#, 'Insecta', 'Arachnida', 'Malacostraca', 'Collembola']
    stats_downloader = HttpDownloader2.new(address: _bold_stats_api(name), destination: file_path)
    no_stats_file = nil

    if failing_taxa.include?(name)
      no_stats_file = true
    else
      begin
        stats_downloader.run
      rescue
        no_stats_file = true
      end
    end

    rank_status = nil
    if no_stats_file
      if reached_genus_level
        rank_status = :genus_rank
      else
        rank_status = :failing_taxon
      end
    else
      if reached_genus_level
        rank_status = :genus_rank
      else
        stats = MiscHelper.json_file_to_hash(file_path)
        num_total_records = stats["total_records"]
        if !num_total_records.nil? && num_total_records == 0
          rank_status = :no_records
        elsif !num_total_records.nil? && num_total_records <= 90_000
          rank_status = :suitable_records_num
        else
          rank_status = :too_many_records
        end
      end
    end

    return rank_status
  end
end
