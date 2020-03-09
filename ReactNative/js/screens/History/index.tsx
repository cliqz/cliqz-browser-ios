import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableWithoutFeedback,
  NativeModules,
} from 'react-native';
import { SwipeListView } from 'react-native-swipe-list-view';
import ListItem from '../../components/ListItem';
import moment from '../../services/moment';

const styles = StyleSheet.create({
  rowFront: {
    alignItems: 'center',
    backgroundColor: 'white',
    borderBottomColor: 'black',
    borderBottomWidth: 0,
    justifyContent: 'center',
    paddingHorizontal: 7,
    paddingVertical: 3,
  },
  backTextWhite: {
    color: '#FFF',
  },
  rowBack: {
    alignItems: 'center',
    backgroundColor: 'red',
    flex: 1,
    flexDirection: 'row',
    justifyContent: 'space-between',
    paddingLeft: 15,
  },
  backRightBtn: {
    alignItems: 'center',
    bottom: 0,
    justifyContent: 'center',
    position: 'absolute',
    top: 0,
    width: 75,
  },
  backRightBtnRight: {
    backgroundColor: 'red',
    right: 0,
  },
});

interface Domain {
  name: string;
  latestVisitDate: number;
}

const PAGE_SIZE = 15;

const useDomains = (): [Domain[], any, any] => {
  const [domains, setDomains] = useState<Domain[]>([]);
  const [page, setPage] = useState(0);
  const [lastLoadedPage, setLastLoadedPage] = useState(-1);

  const loadMore = () => {
    if (page === lastLoadedPage) {
      setPage(page + 1);
    }
  };

  useEffect(() => {
    const fetchDomains = async () => {
      let data: Domain[] = [];
      try {
        data = await NativeModules.History.getDomains(
          PAGE_SIZE,
          page * PAGE_SIZE,
        );
      } catch (e) {
        // In case of the problems with db
      }
      setDomains(prevState => {
        return [...prevState, ...data];
      });
      if (data.length > 0) {
        setLastLoadedPage(page);
      }
    };

    if (page !== lastLoadedPage) {
      fetchDomains();
    }
  }, [page, lastLoadedPage]);

  return [domains, loadMore, setDomains];
};

export default () => {
  const [domains, loadMore, setDomains] = useDomains();

  const renderItem = (data: any) => {
    const { item } = data;
    return (
      <View style={styles.rowFront}>
        <ListItem
          url={item.name}
          title={item.name}
          displayUrl={moment(item.latestVisitDate / 1000).fromNow()}
          onPress={() => {
            NativeModules.HomeViewNavigation.showDomainDetails(item.name);
          }}
          label={null}
        />
      </View>
    );
  };

  const keyExtractor = (item: Domain) => item.name;

  const renderHiddenItem = (data: { item: Domain }) => {
    const { name } = data.item;
    const onPress = async () => {
      await NativeModules.History.removeDomain(name);
      const newData = [...domains];
      const domainToRemoveIndex = domains.findIndex(item => item.name === name);
      newData.splice(domainToRemoveIndex, 1);
      setDomains(newData);
    };

    return (
      <TouchableWithoutFeedback onPress={onPress}>
        <View style={styles.rowBack}>
          <View style={[styles.backRightBtn, styles.backRightBtnRight]}>
            <Text style={styles.backTextWhite}>Delete</Text>
          </View>
        </View>
      </TouchableWithoutFeedback>
    );
  };

  return (
    <SwipeListView
      data={domains}
      disableRightSwipe
      renderItem={renderItem}
      keyExtractor={keyExtractor}
      renderHiddenItem={renderHiddenItem}
      rightOpenValue={-75}
      onEndReached={loadMore}
      onEndReachedThreshold={0.5}
      initialNumToRender={PAGE_SIZE}
    />
  );
};
