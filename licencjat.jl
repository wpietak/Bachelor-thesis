using Random
#using Distributions


mutable struct ProdFactor                                                       # czynnik produkcji
    name::AbstractString
    price::Float64                                                              # cena
    quantity::Float64                                                           # ilość
end

n_pf = 20                                                                       # jest tyle rożnych czynnikow produkcji
init_variable_cost = 8                                                          # początkowa cena każdego
fixed_cost = 100                                                                # koszt stały ustalmy tyle (zawsze)
q_pf = 150                                                                      # początkowa ilość każdego czynnika produkcji

prod_factors = Array{ProdFactor}(undef, n_pf)
[prod_factors[i] = ProdFactor(randstring(8), init_variable_cost, q_pf) for i in 1:n_pf]


mutable struct ConsumerGood                                                     # dobro konsumpcyjne
    name::AbstractString
    demand::Function                                                            # funkcja popytu na nie
    prod_functions::Array{Array}                                                # wektor możliwych funkcji produkcji (każde dobro można wyprodukować na ileś sposobow)
end


mutable struct Entrepreneur                                                     # przedsiębiorca (założmy, że produkuje tylko jedno dobro na raz)
    prediction::Function                                                        # przewidywany przez niego popyt na dane dobro
    receipe::Int64                                                              # z ktorej funkcji produkcji korzysta aby je wyprodukować
    prod_factors_demand::Array{Any}                                             # zapotrzebowanie na środki produkcji w danej iteracji
    resources::Array{Any}                                                       # ile ich dostaje (bo jest ich ograniczona ilość)
    good_i::Int64                                                               # indeks dobra, ktore produkuje w danej iteracji
    planned_production::Float64                                                 # ile chce wyprodukować
    production::Float64                                                         # ile produkuje tego dobra w danej iteracji (ta sama sytuacja co z prod_factors_demand i resources)
    prices::Array{Any}                                                          # po jakiej cenie sprzedaje poszczegolne dobra (może też sprzedawać te, ktore mu zostały w zapasach)
    planned_price::Float64                                                      # i tutaj to samo co z produkcją - jak wyprodukuje mniej niż chciał to nie da tej samej ceny (ale to nie jest wektor tylko pojedyncza wartość, bo to się tyczy jedeynie tego co produkuje)
    profit::Float64                                                             # zysk(strata) w danej iteracji
    stocks::Array{Any}                                                          # niesprzedane zapasy każdego dobra
    stocks_costs::Array{Any}                                                    # koszty wyprodukowania tych zapasow (to nam będzie potrzebne to wyznaczenia zysku (straty) w następnych okresach - będziemy zgodni z zasadami rachunkowości)
end


n_cg = 60                                                                       # liczba dobr konsumpcyjnych, na ktore jest popyt w danym momencie (jest ich dużo więcej niż da się produkować na szeroką skalę - interpretacja w praktyce jest taka, że potrzeby są nieskończone i tak naprawdę możemy sobie wyobrazić nieskończenie wiele dobr kosumpcyjnych, ale dylemat jest na ktore z nich opłaca się przeznaczyć czynniki produkcji)
n_fp = 2                                                                        # na ile sposobow można wyprodukować każde dobro (w tym momencie są tylko dwie możliwe funkcje produkcji dla każdego dobra, ponieważ kiedy było więcej można było użyć praktycznie każdego czynnika do produkcji danego dobra z powodu takiej, a nie innej postaci funkcji przypoporządkowującej dobru funkcje produkcji (czyli przyporządkowującej je w sposob totalnie losowy); gdyby zrobić funkcję, ktora tworzy dla każdego
                                                                                # dobra bardziej zbliżone funkcje produkcji (np. rożniące się tylko proporcjami nakładow, bądź jednym składnikiem), byłoby to bardziej realistyczne i mogłoby być ich więcej)
n_e = 20                                                                        # liczba przedsiębiorcow w gospodarce


setup_cg = Array{ConsumerGood}(undef, n_cg)                                     # tablica z dobrami konsumpcyjnymi

names = Array{AbstractString}(undef, n_cg)
[names[i] = randstring(10) for i in 1:n_cg]                                     # generujemy ich nazwy

r = rand(n_cg,2)
demands = Array{Function}(undef, n_cg)                                          # tablica z funkcjami popytu na każde dobro

for i in 1:n_cg
    demands[i] = function q(p)                                                  # generujemy te funkcje (funkcja postaci q(p)=b+a*p; 200>b>100, -0,2>a>-5)
                    100 + 100*r[i,1] - (4.8*r[i,2]+0.2)*p
                 end
end

prod_functions = Array{Array}(undef, n_cg)                                      # tablica z tablicami z funkcjami produkcji każdego dobra (funkcja to po prostu ile potrzeba każdego składnika, aby wyprodukować jednostkę dobra)

for i in 1:n_cg
    receipes = Array{Array}(undef, n_fp)                                        # tablica z możliwymi funkcjami produkcji konkretnego dobra
    for j in 1:n_fp
        a=rand()*4
        b=rand()*(5-a)
        c=5-a-b                                                                 # aby wyprodukować każde dobro potrzeba 3 rożnych czynnikow produkcji, łącznie 5 jednostek
        receipe = zeros(n_pf)
        receipe[shuffle(1:n_pf)[1:3]] = [a,b,c]
        receipes[j] = receipe                                                   # pojedyncza funkcja produkcji
    end
    prod_functions[i] = receipes
end

for i in 1:n_cg
    setup_cg[i] = ConsumerGood(names[i], demands[i], prod_functions[i])
end


setup_e = Array{Entrepreneur}(undef, n_e)                                       # tablica z przedsiębiorcami
                                                                                # każdy ma jakieś przewidywania co do popytu, ale są one obarczone błędem
std_dev_b = 5                                                                   # odchylenie standardowe pierwszego parametru (b) funkcji
std_dev_a = 0.1                                                                 # odchylenie standardowe drugiego parametru (a) funkcji

for i in 1:n_e

    good_i = rand(1:n_cg)                                                       # indeks dobra, co do ktorego dany przedsiębiorca ma przewidywania popytu (i ktore będzie produkował)

    #predictions = Array{Function}(undef, n_cg)
    #receipes = Array{Array}(undef, n_cg)
    prod_factors_demand = Array{Any}(undef, n_pf)                               # tablica z jego zapotrzebowaniem na poszczegolne czynniki produkcji
    resources = Array{Any}(undef, n_pf)                                         # tablica z ilościami czynnikow, ktore otrzyma
    prices = fill(NaN, n_cg)                                                    # tablica z cenami, po ktorych sprzedaje dobra konsumpcyjne

    b = setup_cg[good_i].demand(0)+std_dev_b*randn()                            # parametr b przewidywanej przez niego funkcji popytu
    a = (setup_cg[good_i].demand(1)-setup_cg[good_i].demand(0))+std_dev_a*randn()    # parametr a przewidywanej przez niego funkcji popytu
    prediction = function q(p)                                                  # generujemy te funkcję
                    b + a*p
                 end

    receipe = rand(1:n_fp)                                                      # ktorą funkcję produkcji wybierze (na początku to bez znaczenia)

    planned_price = (sum(setup_cg[good_i].prod_functions[receipe] .* [prod_factors[j].price for j in 1:n_pf]) - b)/(2*a)   # wstępna cena, po ktrorej chce sprzedawać (jest to rozwiązanie prostego rownania liniowego MR=MC - na początku niech działa jak monopolista, bo i tak nie może nic wiedzieć o innych)
    prices[good_i] = planned_price

    planned_production = prediction(prices[good_i])                                     # wstępna ilość dobra, jaką chce wyprodukować
    production = planned_production

    prod_factors_demand = setup_cg[good_i].prod_functions[receipe] * production # zapotrzebowanie na poszczegolne czynniki produkcji
    resources = prod_factors_demand                                             # na razie ustalamy, że tyle też dostaje, ale może się to zmienić, jeśli się okaże, że inni przedsiębiorcy wykazują takie duże zapotrzebowanie, że nie ma takiej ilości danego czynnika w gospodarce

    setup_e[i] = Entrepreneur(prediction, receipe, prod_factors_demand, resources, good_i, planned_production, production, prices, planned_price, 0, [0 for j=1:n_cg], [0 for j=1:n_cg])     # poki co zysk i zapasy =0

end


function adjust_resources_production(entr_array, prod_factors)                  # funkcja dopasowująca ilości czynnikow, ktore otrzymają przedsiębiorcy (i ile w związku z tym będą mogli wyprodukować i jakie ustalą wtedy ceny)

    market_prod_factor_demand = sum([entr_array[i].prod_factors_demand for i in 1:length(entr_array)])  # obliczamy rynkowe zapotrzebowanie na czynniki produkcji
    pf_i = findall(d -> d == true, [prod_factors[i].quantity for i in 1:length(prod_factors)] .< market_prod_factor_demand)      # na ktore czynniki zapotrzebowanie jest większe niż ich ilość dostępna w gospodarce
    demand_to_pool_ratio = market_prod_factor_demand ./ [prod_factors[i].quantity for i in 1:length(prod_factors)]       # wektor stosunkow zapotrzebowania do puli czynnikow (będzie nam potem potrzebny, aby dopasować ich ceny)

    for i in 1:length(entr_array)                                               # dla każdego przedsiębiorcy sprawdzamy:

        pf_i2 = findall(d -> d > 0, entr_array[i].prod_factors_demand)          # ktore czynniki chce zatrudnić
        pf_i3 = filter(x -> x in pf_i, pf_i2)                                   # czy wśrod nich są jakieś, na ktore jest za duże zapotrzebowanie

        if isempty(pf_i3) == false                                              # jeśli tak, to:
            pf_i4 = argmax(demand_to_pool_ratio[pf_i3])                         # bierzemy ten z nich, na ktory zapotrzebowanie jest największe (w stosunku do ilości)
            x = demand_to_pool_ratio[pf_i3][pf_i4]                              # i liczymy ilukrotnie jest ono za wysokie w stosunku do dostępnej ilości
            entr_array[i].resources = entr_array[i].prod_factors_demand * 1/x   # każdy przedsiębiorca dostanie proporcjonalnie mniej (ale zakładamy, że wtedy innych czynnikow też zatrudnia proporcjonalnie mniej, bo i tak nie miałby co z nimi zrobić - są komplementarne)
            entr_array[i].production = entr_array[i].planned_production * 1/x   # produkcja też się zmniejsza proporcjonalnie siłą rzeczy
            b = entr_array[i].prediction(0)
            a = entr_array[i].prediction(1)-entr_array[i].prediction(0)
            new_Q = entr_array[i].prediction(entr_array[i].planned_price) * 1/x     # przewidywana przez przedsiębiorcę ilość zapotrzebowania, do ktorej należy dopasować cenę
            entr_array[i].prices[entr_array[i].good_i] = (new_Q - b) / a        # nowa cena
        else                                                                    # jeśli nie, to wszystko zgodnie z planem
            entr_array[i].resources = entr_array[i].prod_factors_demand
            entr_array[i].production = entr_array[i].planned_production
            entr_array[i].prices[entr_array[i].good_i] = entr_array[i].planned_price
        end

    end

    return [entr_array, demand_to_pool_ratio]                                   # funkcja zwraca zmienioną tablicę z przedsiębiorcami i powyższy wektor

end


socialism_ratio = 0                                                              # to będzie wspołczynnik wskazujący ile procent czynnikow produkcji nie zmienia cen i ilości (interpretacja jest taka, że są znacjonalizowane, w związku z czym nie biorą udziału w rynkowym procesie wyceny (gdyby zmieniały właściciela, to następowałaby ich prywatyzacja; jako że nie mogą zmienić właściciela, nie możemy mowić o popycie na nie (nie ma on w jaki sposob się urzeczywistnić), a jeśli nie ma zmian popytu,
                                                                                # nie poruszamy się po krzywej podaży - nie ma zatem zmian w cenie i ilości))
private_prod_factors = shuffle(1:length(prod_factors))[1:Int((1-socialism_ratio)*length(prod_factors))]     # losujemy czynniki, ktore zmieniają cenę i ilość

function new_prod_factors_supply(demand_to_pool_ratio, prod_factors, private_prod_factors)            # funkcja dopasowująca podaż czynnikow produkcji do zapotrzebowania na nie

    for i in private_prod_factors

        if prod_factors[i].quantity <= 10 && demand_to_pool_ratio[i] < 1        # ustalimy dolną granicę
            continue
        end
                                                                                # powiedzmy, że właściciele czynnikow produkcji zmieniają ceny według następującego algorytmu:
        #if demand_to_pool_ratio[i] >= 1.5
        #    prod_factors[i].price = prod_factors[i].price * 1.25
        #elseif demand_to_pool_ratio[i] >= 1.2
        #    prod_factors[i].price = prod_factors[i].price * 1.1
        #if demand_to_pool_ratio[i] >= 1.1
        #    prod_factors[i].price = prod_factors[i].price * 1.05
        if demand_to_pool_ratio[i] >= 1.05
            prod_factors[i].price = prod_factors[i].price * 1.025
            prod_factors[i].quantity = prod_factors[i].quantity * 1.025
        elseif demand_to_pool_ratio[i] >= 1.02
            prod_factors[i].price = prod_factors[i].price * 1.01
            prod_factors[i].quantity = prod_factors[i].quantity * 1.01
        elseif demand_to_pool_ratio[i] >= 1.01
            prod_factors[i].price = prod_factors[i].price * 1.005
            prod_factors[i].quantity = prod_factors[i].quantity * 1.005
        elseif 1.01 > demand_to_pool_ratio[i] > 0.99
            prod_factors[i].price = prod_factors[i].price * 1
            prod_factors[i].quantity = prod_factors[i].quantity * 1
        #elseif demand_to_pool_ratio[i] <= 0.5
        #    prod_factors[i].price = prod_factors[i].price * 0.75
        #elseif demand_to_pool_ratio[i] <= 0.8
        #    prod_factors[i].price = prod_factors[i].price * 0.9
        #elseif demand_to_pool_ratio[i] <= 0.9
        #    prod_factors[i].price = prod_factors[i].price * 0.95
        elseif demand_to_pool_ratio[i] <= 0.95
            prod_factors[i].price = prod_factors[i].price * 0.975
            prod_factors[i].quantity = prod_factors[i].quantity * 0.975
        elseif demand_to_pool_ratio[i] <= 0.98
            prod_factors[i].price = prod_factors[i].price * 0.99
            prod_factors[i].quantity = prod_factors[i].quantity * 0.99
        elseif demand_to_pool_ratio[i] <= 0.99
            prod_factors[i].price = prod_factors[i].price * 0.995
            prod_factors[i].quantity = prod_factors[i].quantity * 0.995
        end

    end

    return prod_factors                                                         # funkcja zwraca zmienioną tablicę z czynnikami produkcji

end


function set_profits_stocks_pf_prices(entr_array, cg_array, prod_factors, fixed_cost, private_prod_factors)    # funkcja ustalająca zyski przedsiębiorcow, zapasy, ceny dobr konsumpcyjnych i czynnikow produkcji

    entr_array, demand_to_pool_ratio = adjust_resources_production(entr_array, prod_factors)       # najpierw dopasowujemy produkcję itd.

    leftovers = zeros(length(entr_array))                                       # to będzie wektor z ilościami dobr, ktore zostały wyprodukowane, ale nie zostały sprzedane przez każdego przedsiębiorcę w danej iteracji
    q = zeros(length(entr_array))                                               # to będzie wektor z ilościami dobr, ktore zostały wyprodukowane i zostały sprzedane przez każdego przedsiębiorcę w danej iteracji
    sold_stocks = [zeros(length(cg_array)) for i in 1:length(entr_array)]       # tablica z wektorami z ilościami sprzedanych zapasow w danej iteracji dla każdego przedsiębiorcy
    entr_i = Array{Array}(undef, length(cg_array))                              # tablica zawierająca indeksy przedsiębiorcow produkujących każde dobro
    p = fill(NaN, length(cg_array))                                             # wektor cen
    whole_stocks = zeros(length(cg_array))                                      # ile każdego dobra wszyscy łącznie mają w zapasach
    Q_D = zeros(length(cg_array))                                               # wektor z ilością zapotrzebowania na każde dobro
    Q_S = zeros(length(cg_array))                                               # wektor z sumami wyprodukowanych jednostek każdego dobra
    consumer_surplus = zeros(length(cg_array))                                  # wektor z nadwyżkami konsumenta dla każdego dobra

    for i in 1:length(cg_array)                                                 # potem dla każdego dobra konsumpcyjnego:

        entr_i[i] = findall(x -> x == i, [entr_array[j].good_i for j in 1:length(entr_array)])     # wybieramy przedsiębiorcow, ktorzy je produkują
        p[i] = sort([entr_array[j].prices[i] for j in 1:length(entr_array)])[1]    # wyznaczamy najniższą z oferowanych cen
        if p[i] < 1                                                             # trzeba się zabezpieczyć przed ujemnymi cenami
            p[i] = 1
        end
        whole_stocks[i] = sum([entr_array[j].stocks[i] for j in 1:length(entr_array)])     # ile danego dobra wszyscy łącznie mają w zapasach
        Q_D[i] = cg_array[i].demand(p[i])                                       # ilość zapotrzebowania przy tej cenie
        if Q_D[i] < 0                                                           # w skrajnych przypadkach przedsiębiorcy mylą się na tyle mocno, że po podwyżkach cen związanych z brakiem wystarczającej ilości czynnikow produkcji ustalają ceny, dla ktorych ilość zapotrzebowania jest ujemna
            Q_D[i] = 0
        end
        if isempty(entr_i[i])
            Q_S[i] = 0
        else
            Q_S[i] = sum([entr_array[j].production for j in entr_i[i]])         # suma wyprodukowanych jednostek dobra
        end

    end

    for j in 1:length(entr_array)                                               # dla każdego przedsiębiorcy:

        cg_i = findall(x -> x > 0, entr_array[j].stocks)                        # indeksy dobr, ktorych zapasy posiada

        for i in unique([cg_i..., entr_array[j].good_i])                        # nie wiemy czy jest tam to, ktore produkuje

            entr_array[j].prices[i] = p[i]                                      # zakładamy, że ceny wszystkich przedsiębiorcow automatycznie dopasowują się do najniższej (bo inaczej nic by nie sprzedali)

            b = cg_array[i].demand(0)                                           # tutaj policzymy parametry funkcji popytu, bo będzie nam to potrzebne do wyznaczenia nadwyżki konsumenta (najprościej to zrobić w tym miejscu, bo mamy warunki określone (czy są niedobory itd.))
            a = (cg_array[i].demand(1) - cg_array[i].demand(0))

            if i == entr_array[j].good_i                                        # dla dobra, ktore produkuje:

                if Q_D[i] <= Q_S[i]                                             # jeśli suma wyprodukowanych jednostek danego dobra jest większa niż zapotrzebowanie konsumentow, to:

                    x = Q_S[i] / Q_D[i]                                         # wyznaczamy ilukrotnie je przewyższa
                    q[j] = entr_array[j].production / x                         # każdy sprzedaje proporcjonalnie mniej (a reszta pojdzie do zapasow)
                    sold_stocks[j][i] = 0                                       # 0 zapasow zostaje sprzedanych

                    consumer_surplus[i] = 0.5 * Q_D[i] * ((0 - b) / a - p[i])   # liczymy nadwyżkę konsumenta

                else                                                            # w innym wypadku:

                    q[j] = entr_array[j].production
                    place_for_stocks = Q_D[i] - Q_S[i]                          # jest możliwość sprzedaży zapasow

                    if whole_stocks[i] <= place_for_stocks                      # jeśli suma zapasow danego dobra wszystkich przedsiębiorcow jest mniejsza niż ten niedobor, to:

                        sold_stocks[j][i] = entr_array[j].stocks[i]             # można sprzedać wszystko

                        consumer_surplus[i] = 0.5 * (Q_S[i] + whole_stocks[i]) * ((0 - b) / a - p[i])    # liczymy nadwyżkę konsumenta (tutaj są niedobory, więc niecały popyt zostaje zaspokojony, ale zakładamy, że prawdopodobieństwo, że produkt otrzyma konsument, dla ktorego nadwyżka jest najwyższa i ten, dla ktorego jest najniższa jest takie samo)

                    else

                        y = whole_stocks[i] / place_for_stocks
                        sold_stocks[j][i] = entr_array[j].stocks[i] / y         # w innym wypadku każdy sprzedaje proporcjonalnie mniej

                        consumer_surplus[i] = 0.5 * Q_D[i] * ((0 - b) / a - p[i])   # liczymy nadwyżkę konsumenta

                    end

                end

            else                                                                # dla pozostałych:

                if Q_D[i] <= Q_S[i]                                             # jeśli suma wyprodukowanych jednostek danego dobra jest większa niż zapotrzebowanie konsumentow, to:

                    sold_stocks[j][i] = 0                                       # 0 zapasow zostaje sprzedanych

                    consumer_surplus[i] = 0.5 * Q_D[i] * ((0 - b) / a - p[i])   # liczymy nadwyżkę konsumenta

                else                                                            # w innym wypadku:

                    place_for_stocks = Q_D[i] - Q_S[i]                          # jest możliwość sprzedaży zapasow

                    if whole_stocks[i] <= place_for_stocks                      # jeśli suma zapasow danego dobra wszystkich przedsiębiorcow jest mniejsza niż ten niedobor, to:

                        sold_stocks[j][i] = entr_array[j].stocks[i]             # można sprzedać wszystko
                        entr_array[j].prices[i] = NaN                           # wtedy już go w ogole nie sprzedaje, więc nie można mowić o cenie, ktorą chce zaoferować za nie

                        consumer_surplus[i] = 0.5 * (Q_S[i] + whole_stocks[i]) * ((0 - b) / a - p[i])    # liczymy nadwyżkę konsumenta (tutaj są niedobory, więc niecały popyt zostaje zaspokojony, ale zakładamy, że prawdopodobieństwo, że produkt otrzyma konsument, dla ktorego nadwyżka jest najwyższa i ten, dla ktorego jest najniższa jest takie samo)

                    else

                        y = whole_stocks[i] / place_for_stocks
                        sold_stocks[j][i] = entr_array[j].stocks[i] / y         # w innym wypadku każdy sprzedaje proporcjonalnie mniej

                        consumer_surplus[i] = 0.5 * Q_D[i] * ((0 - b) / a - p[i])   # liczymy nadwyżkę konsumenta

                    end

                end

            end

        end

        which_stocks_1 = findall(x -> x != 0, sold_stocks[j])
        if isempty(which_stocks_1)
            TR = p[entr_array[j].good_i] * q[j]
        else
            TR = p[entr_array[j].good_i] * q[j] + sum(p[which_stocks_1] .* sold_stocks[j][which_stocks_1])          # przychod całkowity (cena produkowanego dobra razy jego ilość, ktora została sprzedana plus wektor cen razy sprzedane ilości zapasow)
        end
        TC_of_production = fixed_cost + entr_array[j].production * sum(cg_array[entr_array[j].good_i].prod_functions[entr_array[j].receipe] .* [prod_factors[l].price for l in 1:length(prod_factors)])    # koszt całkowity produkcji (koszt stały plus wektor odpowiadający odpowiedniej funkcji produkcji razy wektor cen czynnikow produkcji)
        TC_of_prod_per_unit = TC_of_production / entr_array[j].production       # koszt produkcji na jednostkę
        TC = TC_of_prod_per_unit * q[j] + sum(filter(x -> isequal(x,NaN)==false && isequal(x,Inf)==false && isequal(x,-Inf)==false, sold_stocks[j] ./ entr_array[j].stocks .* entr_array[j].stocks_costs))    # "zaksięgowany" koszt całkowity (koszt na jednostkę produkcji plus procent sprzedanych zapasow razy ich koszt (ale trzeba uważać na dzielenie przez 0))
        entr_array[j].profit = TR - TC                                          # zysk
        leftovers[j] = entr_array[j].production - q[j]                          # niesprzedana część produkcji
        entr_array[j].stocks[entr_array[j].good_i] = entr_array[j].stocks[entr_array[j].good_i] + leftovers[j]   # zapasy; powiększamy dotychczasowe o pozostałości...
        entr_array[j].stocks_costs[entr_array[j].good_i] = entr_array[j].stocks_costs[entr_array[j].good_i] + leftovers[j] * TC_of_prod_per_unit     # koszty ich wyprodukowania
        which_stocks_2 = findall(x -> isequal(x,NaN)==false && isequal(x,Inf)==false && isequal(x,-Inf)==false, sold_stocks[j] ./ entr_array[j].stocks .* entr_array[j].stocks_costs)
        if isempty(which_stocks_2) == false
            entr_array[j].stocks_costs[which_stocks_2] = entr_array[j].stocks_costs[which_stocks_2] .- sold_stocks[j][which_stocks_2] ./ entr_array[j].stocks[which_stocks_2] .* entr_array[j].stocks_costs[which_stocks_2]     # pomniejszamy koszty o to, co zostało sprzedane
        end
        entr_array[j].stocks = entr_array[j].stocks .- sold_stocks[j]           # ...i pomniejszamy o sprzedane zapasy

    end

    prod_factors = new_prod_factors_supply(demand_to_pool_ratio, prod_factors, private_prod_factors)

    return [entr_array, prod_factors, q, leftovers, sold_stocks, consumer_surplus]    # funkcja zwraca zaktualizowane tablice z przedsiębiorcami, czynnikami produkcji, wyprodukowanymi i sprzedanymi dobrami, pozostałościami, sprzedanymi zapasami i nadwyżkami konsumenta (to ostatnie jest nam potrzebne, bo to chcemy mierzyć, a reszty będziemy używać w następnej funkcji)

end


function change_production_cg_prices(entr_array, cg_array, prod_factors, fixed_cost, private_prod_factors)   # funkcja reprezentująca dopasowywanie przez przedsiębiorcow produkcji i cen dobr konsumpcyjnych do sytuacji rynkowej

    entr_array, prod_factors, q, leftovers, sold_stocks, consumer_surplus = set_profits_stocks_pf_prices(entr_array, cg_array, prod_factors, fixed_cost, private_prod_factors)

    for j in 1:length(entr_array)                                               # dla każdego przedsiębiorcy:

        cg_supplying_i = findall(x -> isequal(x, NaN) == false, entr_array[j].prices)     # wybieramy dobra, ktore oferuje na sprzedaż (z produkcji lub zapasow)

        for i in cg_supplying_i                                                 # dla każdego z nich:

            if i == entr_array[j].good_i                                        # jeśli jest to dobro, ktore produkuje w danym momencie, to:

                cheapest_receipe = argmin([sum(cg_array[i].prod_functions[l] .* [prod_factors[k].price for k in 1:length(prod_factors)]) for l in 1:length(cg_array[i].prod_functions)])    # najtanisza metoda produkcji
                entr_array[j].receipe = cheapest_receipe                        # przedsiębiorca ją wybierze

                if leftovers[j] > 0                                             # jeśli nie sprzedaje całej produkcji, to:

                    entr_array[j].planned_production = entr_array[j].planned_production * 0.95     # zmniejsza produkcję
                    entr_array[j].planned_price = entr_array[j].planned_price * 0.975    # zmniejsza cenę

                else                                                            # jeśli sprzedaje całą produkcję, to:

                    if entr_array[j].stocks[i] > 0                              # jeśli ma jakieś zapasy, to:

                        if sold_stocks[j][i] > 0                                # jeśli one schodzą, to jest ok - nic nie zmieniamy

                            entr_array[j].planned_production += 0
                            entr_array[j].planned_price += 0

                        else                                                    # jeśli zapasy nie schodzą, ale cała produkcja zostaje sprzedana (mało prawdopodobne), to:

                            entr_array[j].planned_production += 0
                            entr_array[j].planned_price = entr_array[j].planned_price * 0.975      # obniżamy cenę

                        end

                    else                                                        # jeśli nie ma zapasow (i sprzedaje całą produkcję), to znaczy, że popyt jest większy:

                        entr_array[j].planned_production = entr_array[j].planned_production * 1.025
                        entr_array[j].planned_price = entr_array[j].planned_price * 1.025

                    end

                end

            else                                                                # w przypadku dobr, ktorych przedsiębiorca nie produkuje, ale sprzedaje ich zapasy:

                if entr_array[j].stocks[i] > 0                                  # jeśli zapasy są większe niż 0, to:

                    if sold_stocks[j][i] > 0                                    # jeśli one schodzą, to jest ok - nic nie zmieniamy

                        entr_array[j].prices[i] += 0

                    else                                                        # jeśli nie

                        entr_array[j].prices[i] = entr_array[j].prices[i] * 0.95       # obniżamy cenę

                    end

                else                                                            # jeśli nie ma już tych zapasow (sprzedał je w końcu), to możemy zamknąć sprawę

                    entr_array[j].prices[i] = NaN

                end

            end

        end

        entr_array[j].prod_factors_demand = entr_array[j].planned_production * cg_array[entr_array[j].good_i].prod_functions[entr_array[j].receipe]

    end

    return [entr_array, prod_factors, consumer_surplus]

end


function better_profits(entr_array, cg_array, prod_factors, fixed_cost, i_entr, std_dev_b, std_dev_a)    # funkcja reprezentująca dostrzeganie lepszych okazji do zysku przez przedsiębiorcow

    i_cg = rand(1:length(cg_array))                                             # co do ktorego dobra przedsiębiorca będzie miał nowe przewidywania
    i_receipe = argmin([sum(cg_array[i_cg].prod_functions[l] .* [prod_factors[k].price for k in 1:length(prod_factors)]) for l in 1:length(cg_array[i_cg].prod_functions)])    # najtanisza metoda produkcji

    b = cg_array[i_cg].demand(0) + std_dev_b * randn()                          # parametr b przewidywanej przez niego funkcji popytu
    a = (cg_array[i_cg].demand(1) - cg_array[i_cg].demand(0)) + std_dev_a * randn()    # parametr a przewidywanej przez niego funkcji popytu
    prediction = function q(p)                                                  # generujemy tę funkcję
                    b + a*p
                 end

    potential_price_1 = (sum(cg_array[i_cg].prod_functions[i_receipe] .* [prod_factors[j].price for j in 1:length(prod_factors)]) - b) / (2 * a)      # ewentualna cena maksymalizująca zysk
    if potential_price_1 < 1
        potential_price_1 = 1
    end
    potential_q_1 = prediction(potential_price_1)

    e_supplying_i_cg = findall(x -> x == i_cg, [entr_array[j].good_i for j in 1:length(entr_array)])     # zobaczmy, czy ktoś to produkuje (jeśli sprzedają z zapasow, to i tak zaraz zejdzie)
    filter!(x -> x != i_entr, e_supplying_i_cg)                                 # ale oprocz niego

    if isempty(e_supplying_i_cg)                                                # jeśli nie, to:

        potential_price = potential_price_1                                     # ewentualna cena maksymalizująca zysk
        potential_q = potential_q_1                                             # i produkcja

    else                                                                        # jeśli ktoś to produkuje, to:

        potential_price_2 = sort([entr_array[j].prices[i_cg] for j in e_supplying_i_cg])[1] * 0.95      # będzie trzeba obniżyć cenę, aby wejść na rynek
        potential_q_2 = prediction(potential_price_2) / (length(e_supplying_i_cg) + 1)    # powiedzmy, że wtedy każdy będzie rowną część sprzedawał

        if potential_price_2 < potential_price_1
            potential_price = potential_price_2
            potential_q = potential_q_2
        else                                                                    # może da się przejąć większość rynku oferując znacznie niższą cenę (w tym modelu to się może zdarzyć chyba jedynie w przypadku znacznej rożnicy w przewidywaniach, bo aktualnie zawsze wybieramy najtańszą metodę produkcji)
            potential_price = potential_price_1
            potential_q = potential_q_1
        end

    end

    if potential_q < 1                                                          # na wszelki wypadek
        potential_q = 1
    end

    potential_profit = potential_price * potential_q - (fixed_cost + potential_q * sum(cg_array[i_cg].prod_functions[i_receipe] .* [prod_factors[j].price for j in 1:length(prod_factors)]))    # potencjalny zysk

    return [potential_profit, i_cg, i_receipe, potential_price, potential_q, prediction]

end


function go(entr_array, cg_array, prod_factors, fixed_cost, std_dev_b, std_dev_a, n_fp, private_prod_factors, n_iter)   # głowna funkcja (ostatni argument to liczba iteracji)
                                                                                # będziemy mierzyć:
    average_cumulative_consumer_surplus = 0                                     # przeciętną sumę nadwyżek konsumenta
    average_cumulative_profits = 0                                              # przeciętną sumę zyskow przedsiębiorstw
    av_pf_q = 0                                                                 # przeciętną sumę czynnikow produkcji (aby upewnić się że to nie jest ta rzecz, ktora przesądza o wyższej nadwyżce)

    for i in 1:n_iter

        i += -1
        i_entr = rem(i, length(entr_array)) + 1

        entr_array, prod_factors, consumer_surplus = change_production_cg_prices(entr_array, cg_array, prod_factors, fixed_cost, private_prod_factors)

        potential_profit_1, i_cg, i_receipe, potential_price, potential_q, prediction = better_profits(entr_array, cg_array, prod_factors, fixed_cost, i_entr, std_dev_b, std_dev_a)     # potencjalny zysk z produkcji dobra, na ktore przewidział popyt wraz z funkcją produkcji
                                                                                # przedsiębiorca będzie też mogł kopiować od lepszych
        fifth_best_profit = reverse(sort([entr_array[l].profit for l in 1:length(entr_array)]))[5]   # piąty najwyższy zysk
        best_entrs = findall(x -> x >= fifth_best_profit, [entr_array[l].profit for l in 1:length(entr_array)])     # bierzemy pięciu najlepszych przedsiębiorcow
        chosen_entr = shuffle(best_entrs)[1]                                    # losujemy jednego z pięciu najlepszych
        n_entr = length(findall(x -> x == entr_array[chosen_entr].good_i, [entr_array[j].good_i for j in 1:length(entr_array)]))     # ilu produkuje to dobro co on
        potential_profit_2 = n_entr / (n_entr + 1) * 0.8 * entr_array[chosen_entr].profit     # chcąc produkować to dobro przedsiębiorca będzie musiał po pierwsze zwiększyć ilość producenow o 1, co podzieli ich zyski i po drugie obniżyć cenę (natomiast nie wie w jakim stopniu to obniży zyski (przyjmie robocze założenie, że o 20%), ponieważ nie zna funkcji popytu - tylko kopiuje to co robi najlepszy)

        if argmax([entr_array[i_entr].profit + 10, potential_profit_1, potential_profit_2]) == 1    # jeśli te 2 potencjalne zyski nie przewyższają obecnego o pewną minimalną wartość, to:

            entr_array[i_entr].good_i = entr_array[i_entr].good_i               # nie zmieniamy nic

        elseif argmax([entr_array[i_entr].profit + 10, potential_profit_1, potential_profit_2]) == 2    # jeśli największy jest zysk z produkcji dobra z przewidywań, to ustalamy wszystkie dane na temat przedsiębiorcy tka, aby produkował według tych przewidywań:

            entr_array[i_entr].good_i = i_cg
            entr_array[i_entr].receipe = i_receipe
            entr_array[i_entr].planned_production = potential_q
            entr_array[i_entr].production = entr_array[i_entr].planned_production
            entr_array[i_entr].planned_price = potential_price
            entr_array[i_entr].prices[i_cg] = entr_array[i_entr].planned_price
            entr_array[i_entr].prediction = prediction
            entr_array[i_entr].prod_factors_demand = potential_q * cg_array[i_cg].prod_functions[i_receipe]
            entr_array[i_entr].resources = entr_array[i_entr].prod_factors_demand

        elseif argmax([entr_array[i_entr].profit + 10, potential_profit_1, potential_profit_2]) == 3    # w końcu jeśli najbardziej opłaca się kopiować od lepszego, to przedsiębiorca tak robi:

            entr_array[i_entr].good_i = entr_array[chosen_entr].good_i
            entr_array[i_entr].receipe = entr_array[chosen_entr].receipe
            entr_array[i_entr].planned_production = entr_array[chosen_entr].production    # produkcja wstępnie taka sama
            if entr_array[i_entr].planned_production < 1
                entr_array[i_entr].planned_production = 1
            end
            entr_array[i_entr].production = entr_array[i_entr].planned_production
            entr_array[i_entr].planned_price = entr_array[chosen_entr].prices[entr_array[chosen_entr].good_i] * 0.95    # cenę musi obniżyć
            entr_array[i_entr].prices[entr_array[i_entr].good_i] = entr_array[i_entr].planned_price
            entr_array[i_entr].prediction = entr_array[chosen_entr].prediction    # on tak naprawdę nie ma swoich predykcji co do popytu, ale coś musimy tu wstawić, bo jest potrzebne w funkcji adjust_resources_production
            entr_array[i_entr].prod_factors_demand = entr_array[i_entr].planned_production * cg_array[entr_array[i_entr].good_i].prod_functions[entr_array[i_entr].receipe]
            entr_array[i_entr].resources = entr_array[i_entr].prod_factors_demand

        end

        for j in 1:length(entr_array)

            if j == i_entr
                continue
            end

            if entr_array[j].profit < 0                                         # powiedzmy, że w przypadku ponoszenia strat, przedsiębiorca może podejrzeć od jednego z najlepszych, co produkuje (oraz jak) i skopiować

                chosen_entr = shuffle(best_entrs)[1]                            # losujemy jednego z pięciu najlepszych

                entr_array[j].good_i = entr_array[chosen_entr].good_i           # i kopiujemy wszystko
                entr_array[j].receipe = entr_array[chosen_entr].receipe
                entr_array[j].planned_production = entr_array[chosen_entr].production    # produkcja wstępnie taka sama
                if entr_array[j].planned_production < 1
                    entr_array[j].planned_production = 1
                end
                entr_array[j].production = entr_array[j].planned_production
                entr_array[j].planned_price = entr_array[chosen_entr].prices[entr_array[chosen_entr].good_i] * 0.95    # cenę musi obniżyć
                entr_array[j].prices[entr_array[j].good_i] = entr_array[j].planned_price
                entr_array[j].prediction = entr_array[chosen_entr].prediction    # on tak naprawdę nie ma swoich predykcji co do popytu, ale coś musimy tu wstawić, bo jest potrzebne w funkcji adjust_resources_production
                entr_array[j].prod_factors_demand = entr_array[j].planned_production * cg_array[entr_array[j].good_i].prod_functions[entr_array[j].receipe]
                entr_array[j].resources = entr_array[j].prod_factors_demand

            end

        end

        if rem(i, 50) == 49                                                     # co 50. iterację będziemy zmieniali jedno dobro konsumpcyjne i robimy dla niego dokładnie to co na początku dla wszystkich

            i_new_cg = rand(1:length(cg_array))                                 # indeks dobra, ktore zamieni

            r = rand(1,2)

            demand = function qq(p)                                             # generujemy funkcję popytu (funkcja postaci q(p)=b+a*p; 200>b>100, -0,2>a>-5)
                        100 + 100*r[1,1] - (4.8*r[1,2]+0.2)*p
                     end

            prod_functions = Array{Array}(undef, n_fp)                          # tablica z możliwymi funkcjami produkcji tego dobra
            for j in 1:n_fp
                a=rand()*4
                b=rand()*(5-a)
                c=5-a-b                                                         # aby wyprodukować każde dobro potrzeba 3 rożnych czynnikow produkcji, łącznie 5 jednostek
                receipe = zeros(length(prod_factors))
                receipe[shuffle(1:length(prod_factors))[1:3]] = [a,b,c]
                prod_functions[j] = receipe                                     # pojedyncza funkcja produkcji
            end

            cg_array[i_new_cg] = ConsumerGood(randstring(10), demand, prod_functions)   # tworzymy to nowe dobro

            for j in 1:length(entr_array)                                       # ale jeszcze trzeba dostosować przedsiębiorcow do tej zmiany

                entr_array[j].stocks[i_new_cg] = 0                              # zerujemy ich zapasy tego dobra (bo już nie ma szans, żeby je sprzedać - zostanie to odzwierciedlone w zyskach)
                entr_array[j].prices[i_new_cg] = NaN                            # nie możemy też mowić o cenie tego dobra
                entr_array[j].profit = entr_array[j].profit - entr_array[j].stocks_costs[i_new_cg]  # pomniejszamy zyski o koszt wyprodukowania zapasow tego dobra
                entr_array[j].stocks_costs[i_new_cg] = 0                        # i zerujemy koszty produkcji zapasow tego dobra

                while entr_array[j].good_i == i_new_cg                          # jeśli zastąpiliśmy dobro, ktore dany przedsiębiorca produkował, to trzeba mu znaleźć nowe, bo inaczej nie produkowałby nic, ale jest taka kwestia, że nie może być to to nowe dobro (dlatego while, a nie if), gdyż wtedy istnieje ryzyko, że funkcja wzięłaby pomniejszoną delikatnie cenę innego przedsiębiorcy produkującego stare dobro, ale dla ktorego nie zostały jeszcze przyporządkowane nowe
                                                                                # parametry i wtedy np. j-ty przedsiębiorca oferowałby cenę, przy ktorej ilość zapotrzebowania na nowe dobro jest ujemna (w każdym razie zupełnie oderwaną od realiow rynkowych)
                    potential_profit, i_cg, i_receipe, price, q, prediction = better_profits(entr_array, cg_array, prod_factors, fixed_cost, j, std_dev_b, std_dev_a)     # wykorzystamy do tego funkcję better_profits, bo ona robi wszystko, co jest do tego potrzebne
                    entr_array[j].good_i = i_cg
                    entr_array[j].receipe = i_receipe
                    entr_array[j].planned_price = price
                    entr_array[j].prices[i_cg] = price
                    entr_array[j].prediction = prediction
                    entr_array[j].planned_production = q
                    entr_array[j].production = q
                    entr_array[j].prod_factors_demand = entr_array[j].planned_production * cg_array[entr_array[j].good_i].prod_functions[entr_array[j].receipe]
                    entr_array[j].resources = entr_array[j].prod_factors_demand

                end

            end

        end

        cumulative_consumer_surplus = sum(consumer_surplus)                     # suma nadwyżek konsumenta w danej iteracji
        cumulative_profits = sum([entr_array[j].profit for j in 1:length(entr_array)])    # suma zyskow

        average_cumulative_consumer_surplus += cumulative_consumer_surplus / n_iter
        average_cumulative_profits += cumulative_profits / n_iter
        av_pf_q += sum([prod_factors[k].quantity for k in 1:length(prod_factors)]) / n_iter

    end

    return [average_cumulative_consumer_surplus, average_cumulative_profits, av_pf_q]

end


#go(setup_e, setup_cg, prod_factors, fixed_cost, std_dev_b, std_dev_a, n_fp, private_prod_factors, 20000)
