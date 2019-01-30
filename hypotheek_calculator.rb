OUTPUT_FILENAME = 'resultaat_per_maand.csv'
OUTPUT_DIR = "#{File.dirname(__FILE__)}/output/"

print 'Voer hypotheekwaarde in hele euro\'s in... '
begin
  input = gets.chomp
  STARTBEDRAG = input.to_i * 100
  puts "Gekozen hypotheekbedrag: €#{input},00"
rescue
  puts 'Alleen nummers alsjeblieft...'
  retry
end

print 'Voer rente in... '
begin
  input = gets.chomp
  input.gsub!(',','.')
  RENTE = input.to_f / 100
  puts "Gekozen rentepercentage: #{input}%"
rescue
  puts 'Alleen nummers alsjeblieft... Gebruik '.' als decimaalkarakter.'
  retry
end  

print 'Voer looptijd in maanden in... '
begin
  MAANDEN = gets.chomp.to_i
  puts "Gekozen looptijd: #{MAANDEN}"
rescue
  puts 'Alleen nummers alsjeblieft...'
  retry
end

def aflossing_met_rente(maandbedrag, resterend_bedrag)
  inc_rente = (maandbedrag + ((resterend_bedrag * RENTE)/12)).to_i
  rente = inc_rente - maandbedrag
  aflossing = maandbedrag
  {inc_rente: inc_rente.to_i, rente: rente.to_i, aflossing: aflossing.to_i, restant: (resterend_bedrag -= aflossing).to_i}
end

def bereken_maand(laatst_bekende_restant, laatste_berekening)
  begin
    save_value = nil
    result = false
    nieuwe_aflossing = laatste_berekening[:aflossing]

    nieuwe = nil
    while result == false
      nieuwe_aflossing += 1
      nieuwe = aflossing_met_rente(nieuwe_aflossing, laatst_bekende_restant)

      if laatste_berekening[:inc_rente] == nieuwe[:inc_rente]
        result = true
      elsif [laatste_berekening[:inc_rente] + 1, laatste_berekening[:inc_rente] - 1].include? nieuwe[:inc_rente]
        save_value = nieuwe
      elsif nieuwe_aflossing < 0 || nieuwe_aflossing > laatst_bekende_restant
        raise "Fout"
      end

    end
  rescue RuntimeError
    nieuwe = save_value
  end
  nieuwe
end

eerste_aflossing = laatste_aflossing = (STARTBEDRAG / MAANDEN).to_i
resterend_bedrag = STARTBEDRAG
result = false
eerste = nil
laatste = nil

begin
  save_value = nil
  while result == false
    eerste_aflossing = eerste_aflossing - 1
    laatste_aflossing = laatste_aflossing + 1

    eerste = aflossing_met_rente(eerste_aflossing, STARTBEDRAG)
    laatste = aflossing_met_rente(laatste_aflossing, laatste_aflossing)

    eerste_totaal = eerste[:inc_rente]
    laatste_totaal = laatste[:inc_rente]

    if eerste_totaal == laatste_totaal
      result = true
    elsif [eerste_totaal + 1, eerste_totaal - 1].include? laatste_totaal
      save_value = eerste
    elsif eerste_aflossing < 0 || laatste_aflossing > 31000000
      raise 'Fout'
    end
  end
rescue RuntimeError
  eerste = save_value
end

laatst_bekende_restant = resterend_bedrag - eerste[:aflossing]
laatste_berekening = eerste
totaal = [eerste]

(MAANDEN - 1).times do
  nieuwe = bereken_maand(laatst_bekende_restant, laatste_berekening)
  totaal << nieuwe
  laatst_bekende_restant -= nieuwe[:aflossing]
  laatste_berekening = nieuwe
end

totaal_afgelost = STARTBEDRAG
totaal.each do |maand|
  totaal_afgelost -= maand[:aflossing]
end

factor = totaal_afgelost / 360
restant_factor = totaal_afgelost % 360

laatste_berekening = nil

count = 0
totaal.each_with_index do |maand, index|
  begin
    if index == 0
      maand[:aflossing] += factor
      maand[:restant] -= factor
      maand[:inc_rente] += factor
      laatste_berekening = maand
    else
      maand[:aflossing] += factor
      nieuw = aflossing_met_rente(maand[:aflossing], laatste_berekening[:restant])
      maand[:inc_rente] = nieuw[:inc_rente]
      maand[:rente] = nieuw[:rente]
      maand[:restant] = nieuw[:restant]
      laatste_berekening = nieuw
    end
  rescue => e
    puts e
  end

  totaal_afgelost -= factor
  count += factor
end

totaal[-1][:aflossing] += restant_factor
nieuw = aflossing_met_rente(totaal[-1][:aflossing], totaal[-2][:restant])
totaal[-1] = nieuw


resultaat = File.open("#{OUTPUT_DIR}#{OUTPUT_FILENAME}", 'w')
resultaat << "Totaal maandbedrag;Deel aflossing;Deel rente;Restant\n"

totaal.each do |maand|
  resultaat << "#{maand[:inc_rente]};#{maand[:aflossing]};#{maand[:rente]};#{maand[:restant]}\n"
end

puts "Output file #{OUTPUT_FILENAME} saved in #{OUTPUT_DIR}"

fork { exec "open \"#{OUTPUT_DIR}#{OUTPUT_FILENAME}\"" }

resultaat.close
